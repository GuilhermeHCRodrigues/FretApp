// Utilitários das Edge Functions administrativas (sem dependência do Stripe).
import { createClient } from "npm:@supabase/supabase-js@2";

// Cliente admin (service_role). NUNCA usar isso no Flutter.
export const supabaseAdmin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { autoRefreshToken: false, persistSession: false } },
);

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

/** Valida o JWT de quem chamou e confirma que é administrador. */
export function administradorAutenticado(req: Request) {
  return usuarioComPerfil(req, ["administrador"]);
}

/** Administrador ou motorista: quem gerencia o Financeiro. */
export function gestorFinanceiroAutenticado(req: Request) {
  return usuarioComPerfil(req, ["administrador", "motorista"]);
}

/** Valida o JWT de quem chamou e confirma que o perfil é um dos `tipos`. */
async function usuarioComPerfil(req: Request, tipos: string[]) {
  const token = (req.headers.get("Authorization") ?? "")
    .replace(/^Bearer\s+/i, "");
  if (!token) return null;

  const { data, error } = await supabaseAdmin.auth.getUser(token);
  if (error || !data.user) return null;

  const { data: perfil } = await supabaseAdmin
    .from("perfis")
    .select("id, tipo")
    .eq("id", data.user.id)
    .maybeSingle();

  if (!perfil || !tipos.includes(perfil.tipo)) return null;

  return { user: data.user, perfil };
}
