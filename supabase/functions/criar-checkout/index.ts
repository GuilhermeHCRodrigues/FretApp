// Cria uma sessão do Stripe Checkout para o passageiro assinar a mensalidade.
// Chamada pelo Flutter com supabase.functions.invoke('criar-checkout').
import {
  APP_URL,
  corsHeaders,
  json,
  passageiroAutenticado,
  PRICE_ID,
  stripe,
  supabaseAdmin,
} from "../_shared/stripe.ts";

const PIX_HABILITADO = Deno.env.get("STRIPE_PIX_HABILITADO") === "true";

// Status que já contam como assinatura em vigor (não deixa assinar de novo).
const STATUS_EM_VIGOR = ["active", "trialing", "past_due", "unpaid"];

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ erro: "Método não permitido." }, 405);

  try {
    const auth = await passageiroAutenticado(req);
    if (!auth) return json({ erro: "Não autorizado." }, 401);
    const { user, perfil } = auth;

    const { data: assinatura } = await supabaseAdmin
      .from("assinaturas_stripe")
      .select("stripe_customer_id, status")
      .eq("passageiro_id", user.id)
      .maybeSingle();

    if (assinatura?.status && STATUS_EM_VIGOR.includes(assinatura.status)) {
      return json({ erro: "Você já possui uma assinatura ativa." }, 409);
    }

    // Reaproveita o cliente Stripe do passageiro ou cria um novo.
    let customerId = assinatura?.stripe_customer_id as string | undefined;
    if (!customerId) {
      const customer = await stripe.customers.create(
        {
          email: user.email ?? undefined,
          name: perfil.nome_completo ?? undefined,
          metadata: { passageiro_id: user.id },
        },
        { idempotencyKey: `fretapp-customer-${user.id}` },
      );
      customerId = customer.id;

      const { error } = await supabaseAdmin.from("assinaturas_stripe").upsert(
        { passageiro_id: user.id, stripe_customer_id: customerId },
        { onConflict: "passageiro_id" },
      );
      if (error) throw error;
    }

    // deno-lint-ignore no-explicit-any
    const params: any = {
      mode: "subscription",
      customer: customerId,
      client_reference_id: user.id,
      line_items: [{ price: PRICE_ID, quantity: 1 }],
      subscription_data: { metadata: { passageiro_id: user.id } },
      locale: "pt-BR",
      success_url: `${APP_URL}/?pagamento=sucesso`,
      cancel_url: `${APP_URL}/?pagamento=cancelado`,
    };

    if (PIX_HABILITADO) {
      params.payment_method_types = ["card", "pix"];
      params.payment_method_options = {
        pix: {
          mandate_options: {
            reference: "Mensalidade FretApp",
            amount_type: "maximum",
            // Teto mensal autorizado no banco (R$ 250,00), com folga para IOF.
            amount: 25000,
            payment_schedule: "monthly",
          },
        },
      };
    } else {
      params.payment_method_types = ["card"];
    }

    const session = await stripe.checkout.sessions.create(params);
    return json({ url: session.url });
  } catch (e) {
    console.error("criar-checkout:", e);
    return json({ erro: "Não foi possível iniciar o pagamento." }, 500);
  }
});
