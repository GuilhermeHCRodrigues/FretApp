// Abre o Portal do Cliente do Stripe: trocar cartão/PIX, ver faturas, cancelar.
import {
  APP_URL,
  corsHeaders,
  json,
  passageiroAutenticado,
  stripe,
  supabaseAdmin,
} from "../_shared/stripe.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ erro: "Método não permitido." }, 405);

  try {
    const auth = await passageiroAutenticado(req);
    if (!auth) return json({ erro: "Não autorizado." }, 401);

    const { data: assinatura } = await supabaseAdmin
      .from("assinaturas_stripe")
      .select("stripe_customer_id")
      .eq("passageiro_id", auth.user.id)
      .maybeSingle();

    if (!assinatura?.stripe_customer_id) {
      return json({ erro: "Nenhuma assinatura encontrada." }, 404);
    }

    const portal = await stripe.billingPortal.sessions.create({
      customer: assinatura.stripe_customer_id,
      return_url: `${APP_URL}/`,
    });

    return json({ url: portal.url });
  } catch (e) {
    console.error("portal-cliente:", e);
    return json({ erro: "Não foi possível abrir o portal." }, 500);
  }
});
