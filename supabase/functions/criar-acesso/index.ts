// Cria a conta de login de um motorista ou passageiro já cadastrado.
// Só administradores podem chamar. Chamada pelo Flutter com
// supabase.functions.invoke('criar-acesso', body: {...}).
//
// Corpo: { tipo: 'motorista' | 'passageiro', cadastro_id, email, senha }
//
// 1. cria o usuário no Supabase Auth (e-mail já confirmado);
// 2. cria public.perfis com o tipo certo -> ao entrar, o app abre a tela dele;
// 3. grava perfil_id (e o e-mail) no cadastro.
// Se algum passo falhar, o usuário criado é apagado (perfis cai em cascata).
import {
  administradorAutenticado,
  corsHeaders,
  json,
  supabaseAdmin,
} from "../_shared/admin.ts";

const TABELAS = {
  motorista: "motoristas",
  passageiro: "passageiros",
} as const;

type Tipo = keyof typeof TABELAS;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ erro: "Método não permitido." }, 405);

  const auth = await administradorAutenticado(req);
  if (!auth) {
    return json({ erro: "Apenas administradores podem criar acessos." }, 403);
  }

  let corpo: Record<string, unknown>;
  try {
    corpo = await req.json();
  } catch {
    return json({ erro: "Requisição inválida." }, 400);
  }

  const tipo = corpo.tipo as Tipo;
  const cadastroId = String(corpo.cadastro_id ?? "");
  const email = String(corpo.email ?? "").trim().toLowerCase();
  const senha = String(corpo.senha ?? "");

  if (!(tipo in TABELAS)) return json({ erro: "Tipo de usuário inválido." }, 400);
  if (!UUID.test(cadastroId)) return json({ erro: "Cadastro inválido." }, 400);
  if (!EMAIL.test(email)) return json({ erro: "Informe um e-mail válido." }, 400);
  if (senha.length < 8 || senha.length > 72) {
    return json({ erro: "A senha deve ter entre 8 e 72 caracteres." }, 400);
  }

  const tabela = TABELAS[tipo];

  try {
    const { data: cadastro, error: erroCadastro } = await supabaseAdmin
      .from(tabela)
      .select("id, nome, telefone, perfil_id")
      .eq("id", cadastroId)
      .maybeSingle();

    if (erroCadastro) throw erroCadastro;
    if (!cadastro) return json({ erro: "Cadastro não encontrado." }, 404);
    if (cadastro.perfil_id) {
      return json({ erro: "Este cadastro já possui acesso ao app." }, 409);
    }

    const { data: criado, error: erroAuth } = await supabaseAdmin.auth.admin
      .createUser({
        email,
        password: senha,
        email_confirm: true,
        user_metadata: { nome_completo: cadastro.nome, tipo },
      });

    if (erroAuth || !criado.user) {
      // deno-lint-ignore no-explicit-any
      const codigo = (erroAuth as any)?.code;
      if (codigo === "email_exists" || codigo === "user_already_exists" ||
          erroAuth?.status === 422) {
        return json({ erro: "Já existe uma conta com este e-mail." }, 409);
      }
      if (codigo === "weak_password") {
        return json({ erro: "Senha fraca. Use letras, números e símbolos." }, 400);
      }
      throw erroAuth ?? new Error("Usuário não criado.");
    }

    const usuarioId = criado.user.id;

    try {
      const { error: erroPerfil } = await supabaseAdmin.from("perfis").insert({
        id: usuarioId,
        tipo,
        nome_completo: cadastro.nome,
        telefone: cadastro.telefone ?? null,
      });
      if (erroPerfil) throw erroPerfil;

      // `perfil_id is null` evita corrida entre dois administradores.
      const { data: vinculado, error: erroVinculo } = await supabaseAdmin
        .from(tabela)
        .update({ perfil_id: usuarioId, email })
        .eq("id", cadastroId)
        .is("perfil_id", null)
        .select("id");
      if (erroVinculo) throw erroVinculo;
      if (!vinculado || vinculado.length === 0) {
        throw new Error("Cadastro vinculado por outra requisição.");
      }
    } catch (e) {
      await supabaseAdmin.auth.admin.deleteUser(usuarioId);
      throw e;
    }

    return json({ perfil_id: usuarioId, email });
  } catch (e) {
    console.error("criar-acesso:", e);
    return json({ erro: "Não foi possível criar o acesso. Tente novamente." }, 500);
  }
});
