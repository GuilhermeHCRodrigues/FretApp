// Recebe eventos do Stripe e sincroniza:
//   - public.assinaturas_stripe  (status da assinatura)
//   - public.mensalidades        (uma linha por passageiro + competência)
//   - public.pagamentos          (provedor 'stripe', referencia_externa = fatura)
// Deploy sem verificação de JWT: a autenticidade vem da assinatura do Stripe.
import Stripe from "npm:stripe@^19";
import { json, stripe, supabaseAdmin } from "../_shared/stripe.ts";

const WEBHOOK_SECRET = Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? "";
const cryptoProvider = Stripe.createSubtleCryptoProvider();
const FUSO = "America/Sao_Paulo";

function id(valor: string | { id: string } | null | undefined) {
  if (!valor) return null;
  return typeof valor === "string" ? valor : valor.id;
}

function dataIso(segundos?: number | null) {
  return segundos ? new Date(segundos * 1000).toISOString() : null;
}

/** Data local (Brasília) no formato YYYY-MM-DD. */
function dataLocal(segundos: number) {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: FUSO,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date(segundos * 1000));
}

async function passageiroPorCustomer(customerId: string | null) {
  if (!customerId) return null;
  const { data } = await supabaseAdmin
    .from("assinaturas_stripe")
    .select("passageiro_id")
    .eq("stripe_customer_id", customerId)
    .maybeSingle();
  return (data?.passageiro_id as string | undefined) ?? null;
}

async function sincronizarAssinatura(sub: Stripe.Subscription) {
  const customerId = id(sub.customer);
  const passageiroId = sub.metadata?.passageiro_id ??
    await passageiroPorCustomer(customerId);

  if (!passageiroId || !customerId) {
    console.warn("Assinatura sem passageiro associado:", sub.id);
    return;
  }

  // Nas versões recentes da API o período fica no item da assinatura.
  // deno-lint-ignore no-explicit-any
  const item = sub.items.data[0] as any;
  // deno-lint-ignore no-explicit-any
  const periodoFim = item?.current_period_end ?? (sub as any).current_period_end;

  const { error } = await supabaseAdmin.from("assinaturas_stripe").upsert(
    {
      passageiro_id: passageiroId,
      stripe_customer_id: customerId,
      stripe_subscription_id: sub.id,
      status: sub.status,
      periodo_fim: dataIso(periodoFim),
      cancelar_no_fim: sub.cancel_at_period_end,
      atualizado_em: new Date().toISOString(),
    },
    { onConflict: "passageiro_id" },
  );
  if (error) throw error;
}

type Tentativa = "falhou" | null;

function statusMensalidade(invoice: Stripe.Invoice, tentativa: Tentativa) {
  switch (invoice.status) {
    case "paid":
      return "paga";
    case "void":
      return "cancelada";
    case "uncollectible":
      return "vencida";
    default:
      return tentativa === "falhou" ? "vencida" : "pendente";
  }
}

function statusPagamento(invoice: Stripe.Invoice, tentativa: Tentativa) {
  switch (invoice.status) {
    case "paid":
      return "aprovado";
    case "void":
      return "cancelado";
    case "uncollectible":
      return "rejeitado";
    default:
      return tentativa === "falhou" ? "rejeitado" : "pendente";
  }
}

async function registrarFatura(evento: Stripe.Invoice, tentativa: Tentativa) {
  if (!evento.id) return;

  // Eventos podem chegar fora de ordem (ex.: "finalized" depois de "paid").
  // Buscar a fatura atual evita rebaixar uma mensalidade já paga.
  const invoice = await stripe.invoices.retrieve(evento.id);
  if (invoice.status === "paid") tentativa = null;

  const valor = invoice.status === "paid" ? invoice.amount_paid : invoice.amount_due;
  // As tabelas exigem valor > 0 (fatura zerada = período de teste, ignora).
  if (!valor || valor <= 0) return;

  const passageiroId = await passageiroPorCustomer(id(invoice.customer));
  if (!passageiroId) {
    console.warn("Fatura sem passageiro associado:", invoice.id);
    return;
  }

  // Competência = mês em que começa o período cobrado (horário de Brasília).
  const inicioPeriodo = invoice.lines?.data?.[0]?.period?.start ?? invoice.created;
  const competencia = `${dataLocal(inicioPeriodo).slice(0, 7)}-01`;
  const vencimento = dataLocal(invoice.due_date ?? inicioPeriodo);

  const { data: mensalidade, error: erroMensalidade } = await supabaseAdmin
    .from("mensalidades")
    .upsert(
      {
        passageiro_id: passageiroId,
        competencia,
        valor_centavos: valor,
        vencimento,
        status: statusMensalidade(invoice, tentativa),
      },
      { onConflict: "passageiro_id,competencia" },
    )
    .select("id")
    .single();
  if (erroMensalidade) throw erroMensalidade;

  const { error: erroPagamento } = await supabaseAdmin
    .from("pagamentos")
    .upsert(
      {
        mensalidade_id: mensalidade.id,
        provedor: "stripe",
        referencia_externa: invoice.id,
        valor_centavos: valor,
        status: statusPagamento(invoice, tentativa),
        pago_em: dataIso(invoice.status_transitions?.paid_at),
      },
      { onConflict: "provedor,referencia_externa" },
    );
  if (erroPagamento) throw erroPagamento;
}

Deno.serve(async (req) => {
  const assinatura = req.headers.get("Stripe-Signature");
  if (!assinatura) return json({ erro: "Sem assinatura." }, 400);

  let event: Stripe.Event;
  try {
    const corpo = await req.text();
    event = await stripe.webhooks.constructEventAsync(
      corpo,
      assinatura,
      WEBHOOK_SECRET,
      undefined,
      cryptoProvider,
    );
  } catch (e) {
    console.error("Assinatura de webhook inválida:", e);
    return json({ erro: "Assinatura inválida." }, 400);
  }

  try {
    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object as Stripe.Checkout.Session;
        const subId = id(session.subscription);
        if (subId) {
          await sincronizarAssinatura(await stripe.subscriptions.retrieve(subId));
        }
        break;
      }
      case "customer.subscription.created":
      case "customer.subscription.updated":
      case "customer.subscription.deleted":
        await sincronizarAssinatura(event.data.object as Stripe.Subscription);
        break;
      case "invoice.finalized":
      case "invoice.paid":
      case "invoice.voided":
      case "invoice.marked_uncollectible":
        await registrarFatura(event.data.object as Stripe.Invoice, null);
        break;
      case "invoice.payment_failed":
        await registrarFatura(event.data.object as Stripe.Invoice, "falhou");
        break;
      default:
        break;
    }
    return json({ recebido: true });
  } catch (e) {
    // 500 faz o Stripe reenviar o evento depois.
    console.error(`Erro ao processar ${event.type}:`, e);
    return json({ erro: "Falha ao processar evento." }, 500);
  }
});
