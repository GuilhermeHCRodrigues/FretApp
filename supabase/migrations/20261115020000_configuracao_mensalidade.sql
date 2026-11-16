-- FretApp - valor da mensalidade alterável pelo administrador.
--
-- No Stripe um preço (price_...) não pode ter o valor editado. Para mudar a
-- mensalidade, a Edge Function `mensalidade-stripe` cria um preço novo no
-- mesmo produto, torna-o o padrão e grava aqui qual é o preço vigente.
-- `criar-checkout` passa a usar este preço; o app lê o valor para exibir.
--
-- Enquanto não houver linha, as funções usam o STRIPE_PRICE_ID padrão.
-- Execute no SQL Editor do Supabase.

CREATE TABLE IF NOT EXISTS public.configuracao_mensalidade (
  -- Tabela de uma linha só.
  id boolean PRIMARY KEY DEFAULT true CHECK (id),
  stripe_price_id text NOT NULL,
  valor_centavos integer NOT NULL CHECK (valor_centavos > 0),
  moeda text NOT NULL DEFAULT 'brl',
  atualizado_em timestamptz NOT NULL DEFAULT now(),
  atualizado_por uuid REFERENCES public.perfis(id) ON DELETE SET NULL
);

ALTER TABLE public.configuracao_mensalidade ENABLE ROW LEVEL SECURITY;

-- Todos os usuários logados podem ver o valor (o passageiro vê na tela dele).
-- Ninguém grava pelo app: só a Edge Function, com a service_role.
DROP POLICY IF EXISTS "Usuarios consultam valor da mensalidade"
  ON public.configuracao_mensalidade;
CREATE POLICY "Usuarios consultam valor da mensalidade"
  ON public.configuracao_mensalidade
  FOR SELECT TO authenticated
  USING (true);

REVOKE ALL ON public.configuracao_mensalidade FROM anon, authenticated;
GRANT SELECT ON public.configuracao_mensalidade TO authenticated;
