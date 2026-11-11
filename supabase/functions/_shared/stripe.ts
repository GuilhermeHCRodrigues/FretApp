// Utilitários compartilhados pelas Edge Functions do Financeiro.
import Stripe from "npm:stripe@^19";
import { createClient } from "npm:@supabase/supabase-js@2";

// Versão fixa da API: inclui suporte a Pix Automático (assinatura com Pix).
export const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
  // deno-lint-ignore no-explicit-any
  apiVersion: "2026-04-22.dahlia" as any,
  httpClient: Stripe.createFetchHttpClient(),
});

// Cliente admin (service_role). NUNCA usar isso no Flutter.
export const supabaseAdmin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

export const APP_URL = (Deno.env.get("APP_URL") ?? "http://localhost:5000")
  .replace(/\/$/, "");

// Preço "Mensalidade FretApp" (R$ 200,00/mês, modo de teste).
export const PRICE_ID = Deno.env.get("STRIPE_PRICE_ID") ??
  "price_1UaOMiD698ukJERUc9h2Fuo2";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/** Valida o JWT do usuário e confirma que ele é passageiro. */
export async function passageiroAutenticado(req: Request) {
  const token = (req.headers.get("Authorization") ?? "")
    .replace(/^Bearer\s+/i, "");
  if (!token) return null;

  const { data, error } = await supabaseAdmin.auth.getUser(token);
  if (error || !data.user) return null;

  const { data: perfil } = await supabaseAdmin
    .from("perfis")
    .select("id, tipo, nome_completo")
    .eq("id", data.user.id)
    .maybeSingle();

  if (!perfil || perfil.tipo !== "passageiro") return null;

  return { user: data.user, perfil };
}
