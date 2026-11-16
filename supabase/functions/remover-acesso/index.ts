// Remove a conta de login (Supabase Auth + perfis) de um motorista ou
// passageiro. Só administradores podem chamar.
//
// Corpo: { perfil_id }            -> remove a conta
//        { acao: "listar", tipo? } -> contas sem cadastro (com e-mail)
//
// Sem isso, excluir só o cadastro deixava o login vivo: o e-mail continuava
// "em uso" (bloqueava criar o acesso de novo) e a conta aparecia no
// Financeiro como "Passageiro sem nome".
//
// O Auth não apaga o usuário enquanto houver registros com FK RESTRICT para
// perfis (mensalidades, assinaturas, reservas, embarques, viagens). Por isso,
// antes de apagar:
//   1. cancela no Stripe a assinatura em vigor (senão continuaria cobrando);
//   2. apaga pagamentos, mensalidades, assinatura, embarques e reservas dele;
//   3. tira o motorista das viagens (motorista_id = null);
//   4. desvincula os cadastros (perfil_id = null).
// O resto (confirmações da enquete, leituras de mensagens, localização) cai
// em cascata quando o usuário é apagado.
import {
  administradorAutenticado,
  corsHeaders,
  json,
  supabaseAdmin,
} from "../_shared/admin.ts";
import { stripe } from "../_shared/stripe.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const EM_VIGOR = ["active", "trialing", "past_due", "unpaid", "incomplete", "paused"];

function falhou(etapa: string, erro: unknown): never {
  console.error(`remover-acesso (${etapa}):`, erro);
  throw new Error(etapa);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ erro: "Método não permitido." }, 405);

  const auth = await administradorAutenticado(req);
  if (!auth) {
    return json({ erro: "Apenas administradores podem remover acessos." }, 403);
  }

  let corpo: Record<string, unknown>;
  try {
    corpo = await req.json();
  } catch {
    return json({ erro: "Requisição inválida." }, 400);
  }

  if (corpo.acao === "listar") return await listarOrfas(corpo.tipo);

  const perfilId = String(corpo.perfil_id ?? "");
  if (!UUID.test(perfilId)) return json({ erro: "Conta inválida." }, 400);
  if (perfilId === auth.user.id) {
    return json({ erro: "Você não pode remover a própria conta." }, 400);
  }

  const { data: perfil, error: erroPerfil } = await supabaseAdmin
    .from("perfis")
    .select("id, tipo")
    .eq("id", perfilId)
    .maybeSingle();
  if (erroPerfil) return json({ erro: "Não foi possível consultar a conta." }, 500);

  if (perfil && !["motorista", "passageiro"].includes(perfil.tipo)) {
    return json({ erro: "Só contas de motorista ou passageiro podem ser removidas." }, 400);
  }

  try {
    // 1. Assinatura no Stripe.
    const { data: assinatura } = await supabaseAdmin
      .from("assinaturas_stripe")
      .select("stripe_subscription_id, status")
      .eq("passageiro_id", perfilId)
      .maybeSingle();
    const assinaturaId = assinatura?.stripe_subscription_id as string | null;
    if (assinaturaId && EM_VIGOR.includes(String(assinatura?.status))) {
      try {
        await stripe.subscriptions.cancel(assinaturaId);
      } catch (e) {
        // deno-lint-ignore no-explicit-any
        if ((e as any)?.code !== "resource_missing") falhou("cancelar assinatura", e);
      }
    }

    // 2. Financeiro e reservas.
    const { data: mensalidades, error: e1 } = await supabaseAdmin
      .from("mensalidades")
      .select("id")
      .eq("passageiro_id", perfilId);
    if (e1) falhou("ler mensalidades", e1);
    const idsMensalidades = (mensalidades ?? []).map((m) => m.id);
    if (idsMensalidades.length > 0) {
      const { error } = await supabaseAdmin
        .from("pagamentos").delete().in("mensalidade_id", idsMensalidades);
      if (error) falhou("apagar pagamentos", error);
      const { error: e2 } = await supabaseAdmin
        .from("mensalidades").delete().in("id", idsMensalidades);
      if (e2) falhou("apagar mensalidades", e2);
    }
    {
      const { error } = await supabaseAdmin
        .from("assinaturas_stripe").delete().eq("passageiro_id", perfilId);
      if (error) falhou("apagar assinatura", error);
    }

    const { data: reservas, error: e3 } = await supabaseAdmin
      .from("reservas").select("id").eq("passageiro_id", perfilId);
    if (e3) falhou("ler reservas", e3);
    const idsReservas = (reservas ?? []).map((r) => r.id);
    if (idsReservas.length > 0) {
      const { error } = await supabaseAdmin
        .from("embarques").delete().in("reserva_id", idsReservas);
      if (error) falhou("apagar embarques das reservas", error);
    }
    {
      const { error } = await supabaseAdmin
        .from("embarques").delete().eq("registrado_por", perfilId);
      if (error) falhou("apagar embarques registrados", error);
    }
    if (idsReservas.length > 0) {
      const { error } = await supabaseAdmin
        .from("reservas").delete().in("id", idsReservas);
      if (error) falhou("apagar reservas", error);
    }

    // 3. Viagens em que era o motorista continuam, sem motorista.
    {
      const { error } = await supabaseAdmin
        .from("viagens").update({ motorista_id: null }).eq("motorista_id", perfilId);
      if (error) falhou("tirar motorista das viagens", error);
    }

    // 4. Cadastros ficam sem acesso (podem ganhar um novo depois).
    for (const tabela of ["passageiros", "motoristas"]) {
      const { error } = await supabaseAdmin
        .from(tabela).update({ perfil_id: null }).eq("perfil_id", perfilId);
      if (error) falhou(`desvincular ${tabela}`, error);
    }

    // 5. Apaga o login (perfis cai em cascata).
    const { error: erroAuth } = await supabaseAdmin.auth.admin.deleteUser(perfilId);
    if (erroAuth && erroAuth.status !== 404) falhou("apagar usuário", erroAuth);

    // Usuário já não existia no Auth, mas sobrou o perfil.
    if (erroAuth?.status === 404 && perfil) {
      const { error } = await supabaseAdmin.from("perfis").delete().eq("id", perfilId);
      if (error) falhou("apagar perfil", error);
    }

    return json({ removido: perfilId });
  } catch (e) {
    return json({
      erro: `Não foi possível remover o acesso (${(e as Error).message}). ` +
        "Tente novamente.",
    }, 500);
  }
});

/**
 * Contas de motorista/passageiro sem cadastro ligado (ou logins sem perfil).
 * O e-mail só existe no Auth, que o app não consegue ler.
 */
async function listarOrfas(tipo: unknown) {
  try {
    const [perfis, passageiros, motoristas] = await Promise.all([
      supabaseAdmin.from("perfis").select("id, tipo, nome_completo, telefone"),
      supabaseAdmin.from("passageiros").select("perfil_id").not("perfil_id", "is", null),
      supabaseAdmin.from("motoristas").select("perfil_id").not("perfil_id", "is", null),
    ]);
    for (const r of [perfis, passageiros, motoristas]) if (r.error) throw r.error;

    const vinculados = new Set(
      [...passageiros.data!, ...motoristas.data!].map((c) => c.perfil_id as string),
    );
    const perfilPorId = new Map(perfis.data!.map((p) => [p.id as string, p]));

    const usuarios = [];
    for (let pagina = 1; pagina <= 20; pagina++) {
      const { data, error } = await supabaseAdmin.auth.admin.listUsers({
        page: pagina,
        perPage: 200,
      });
      if (error) throw error;
      usuarios.push(...data.users);
      if (data.users.length < 200) break;
    }

    const orfas = [];
    for (const u of usuarios) {
      const p = perfilPorId.get(u.id);
      const tipoConta = (p?.tipo as string | undefined) ?? null;
      if (tipoConta === "administrador" || vinculados.has(u.id)) continue;
      if (tipo && tipoConta && tipoConta !== tipo) continue;
      orfas.push({
        perfil_id: u.id,
        email: u.email ?? null,
        tipo: tipoConta,
        nome: p?.nome_completo ?? null,
        telefone: p?.telefone ?? null,
        criado_em: u.created_at,
      });
    }
    return json({ contas: orfas });
  } catch (e) {
    console.error("remover-acesso (listar):", e);
    return json({ erro: "Não foi possível listar as contas sem cadastro." }, 500);
  }
}
