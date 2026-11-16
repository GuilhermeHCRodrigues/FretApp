// Valor da mensalidade no Stripe, gerenciado pelo administrador ou motorista.
// Chamada pelo Flutter com supabase.functions.invoke('mensalidade-stripe').
//
// { acao: 'consultar' }
//   -> { valor_centavos, moeda, price_id, assinaturas }
//
// { acao: 'alterar', valor_centavos, aplicar_assinaturas: boolean }
//   No Stripe o valor de um preço não pode ser editado. Então:
//   1. cria um preço novo no mesmo produto (mesma moeda e recorrência);
//   2. torna-o o preço padrão do produto e grava em configuracao_mensalidade
//      (criar-checkout passa a usá-lo nas próximas assinaturas);
//   3. se aplicar_assinaturas, troca o preço das assinaturas em vigor sem
//      cobrança proporcional: o valor novo vale a partir da próxima fatura.
//   -> { valor_centavos, price_id, atualizadas, falhas }
import Stripe from "npm:stripe@^19";
import { gestorFinanceiroAutenticado } from "../_shared/admin.ts";
import {
  corsHeaders,
  json,
  precoAtual,
  stripe,
  supabaseAdmin,
} from "../_shared/stripe.ts";

// R$ 1,00 a R$ 10.000,00.
const MINIMO = 100;
const MAXIMO = 1_000_000;

// Assinaturas que ainda vão gerar cobrança.
const EM_VIGOR = new Set(["active", "trialing", "past_due", "unpaid"]);

function produtoDe(preco: Stripe.Price) {
  return typeof preco.product === "string" ? preco.product : preco.product.id;
}

/** Assinaturas em vigor que cobram algum preço deste produto. */
async function assinaturasDoProduto(produto: string) {
  const encontradas: { assinatura: string; item: string; preco: string }[] = [];
  for await (
    const sub of stripe.subscriptions.list({
      status: "all",
      limit: 100,
      expand: ["data.items.data.price"],
    })
  ) {
    if (!EM_VIGOR.has(sub.status)) continue;
    for (const item of sub.items.data) {
      if (produtoDe(item.price) === produto) {
        encontradas.push({
          assinatura: sub.id,
          item: item.id,
          preco: item.price.id,
        });
      }
    }
  }
  return encontradas;
}

async function consultar() {
  const preco = await stripe.prices.retrieve(await precoAtual());
  const assinaturas = await assinaturasDoProduto(produtoDe(preco));
  return json({
    valor_centavos: preco.unit_amount,
    moeda: preco.currency,
    price_id: preco.id,
    assinaturas: assinaturas.length,
  });
}

async function alterar(
  adminId: string,
  valor: number,
  aplicarAssinaturas: boolean,
) {
  const antigo = await stripe.prices.retrieve(await precoAtual());
  const produto = produtoDe(antigo);

  let novo = antigo;
  if (antigo.unit_amount !== valor) {
    novo = await stripe.prices.create(
      {
        product: produto,
        currency: antigo.currency,
        unit_amount: valor,
        recurring: {
          interval: antigo.recurring?.interval ?? "month",
          interval_count: antigo.recurring?.interval_count ?? 1,
        },
        nickname: "Mensalidade FretApp",
        metadata: { alterado_por: adminId, preco_anterior: antigo.id },
      },
      // Evita criar dois preços se o administrador clicar duas vezes.
      { idempotencyKey: `fretapp-preco-${antigo.id}-${valor}` },
    );
    await stripe.products.update(produto, { default_price: novo.id });
    // O preço antigo continua cobrando quem não for migrado; só sai da lista
    // de preços disponíveis para novas assinaturas.
    await stripe.prices.update(antigo.id, { active: false });
  }

  const { error } = await supabaseAdmin.from("configuracao_mensalidade")
    .upsert({
      id: true,
      stripe_price_id: novo.id,
      valor_centavos: valor,
      moeda: novo.currency,
      atualizado_em: new Date().toISOString(),
      atualizado_por: adminId,
    });
  if (error) throw error;

  let atualizadas = 0;
  let falhas = 0;
  if (aplicarAssinaturas) {
    for (const a of await assinaturasDoProduto(produto)) {
      if (a.preco === novo.id) continue;
      try {
        await stripe.subscriptions.update(a.assinatura, {
          items: [{ id: a.item, price: novo.id }],
          proration_behavior: "none",
        });
        atualizadas++;
      } catch (e) {
        console.error("mensalidade-stripe: assinatura", a.assinatura, e);
        falhas++;
      }
    }
  }

  return json({
    valor_centavos: valor,
    price_id: novo.id,
    atualizadas,
    falhas,
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ erro: "Método não permitido." }, 405);

  const auth = await gestorFinanceiroAutenticado(req);
  if (!auth) {
    return json(
      { erro: "Apenas administradores e motoristas podem alterar a mensalidade." },
      403,
    );
  }

  let corpo: Record<string, unknown>;
  try {
    corpo = await req.json();
  } catch {
    return json({ erro: "Requisição inválida." }, 400);
  }

  try {
    if (corpo.acao === "consultar") return await consultar();

    if (corpo.acao === "alterar") {
      const valor = Number(corpo.valor_centavos);
      if (!Number.isInteger(valor) || valor < MINIMO || valor > MAXIMO) {
        return json(
          { erro: "Informe um valor entre R$ 1,00 e R$ 10.000,00." },
          400,
        );
      }
      return await alterar(
        auth.user.id,
        valor,
        corpo.aplicar_assinaturas === true,
      );
    }

    return json({ erro: "Ação inválida." }, 400);
  } catch (e) {
    console.error("mensalidade-stripe:", e);
    return json({ erro: "Não foi possível falar com o Stripe. Tente novamente." }, 500);
  }
});
