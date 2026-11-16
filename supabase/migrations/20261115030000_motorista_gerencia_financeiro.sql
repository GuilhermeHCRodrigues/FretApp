-- FretApp - o motorista gerencia o Financeiro igual ao administrador.
--
-- O motorista não paga mensalidade (o checkout só aceita passageiros e a
-- tabela do Financeiro só lista passageiros). Esta migration apenas dá a ele
-- a mesma LEITURA que o administrador tem no Financeiro:
--   perfis dos passageiros, cadastro de passageiros, mensalidades,
--   pagamentos e assinaturas do Stripe.
-- Alterar o valor da mensalidade é feito pela Edge Function
-- `mensalidade-stripe`, que passa a aceitar motoristas também.
--
-- As políticas abaixo só ADICIONAM leitura; as do administrador e do
-- passageiro continuam como estão. Execute no SQL Editor do Supabase.

CREATE OR REPLACE FUNCTION public.fretapp_gerencia_financeiro()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.perfis p
    WHERE p.id = (SELECT auth.uid())
      AND p.tipo IN ('administrador', 'motorista')
  );
$$;

REVOKE ALL ON FUNCTION public.fretapp_gerencia_financeiro() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fretapp_gerencia_financeiro() TO authenticated;

-- Contas de passageiros (nome, telefone, instituição) — só tipo passageiro.
DROP POLICY IF EXISTS "Financeiro consulta perfis de passageiros" ON public.perfis;
CREATE POLICY "Financeiro consulta perfis de passageiros"
  ON public.perfis
  FOR SELECT TO authenticated
  USING (tipo = 'passageiro' AND (SELECT public.fretapp_gerencia_financeiro()));

-- Cadastro dos passageiros feito pelo administrador (somente leitura).
DROP POLICY IF EXISTS "Financeiro consulta passageiros" ON public.passageiros;
CREATE POLICY "Financeiro consulta passageiros"
  ON public.passageiros
  FOR SELECT TO authenticated
  USING ((SELECT public.fretapp_gerencia_financeiro()));

DROP POLICY IF EXISTS "Financeiro consulta mensalidades" ON public.mensalidades;
CREATE POLICY "Financeiro consulta mensalidades"
  ON public.mensalidades
  FOR SELECT TO authenticated
  USING ((SELECT public.fretapp_gerencia_financeiro()));

DROP POLICY IF EXISTS "Financeiro consulta pagamentos" ON public.pagamentos;
CREATE POLICY "Financeiro consulta pagamentos"
  ON public.pagamentos
  FOR SELECT TO authenticated
  USING ((SELECT public.fretapp_gerencia_financeiro()));

DROP POLICY IF EXISTS "Financeiro consulta assinaturas" ON public.assinaturas_stripe;
CREATE POLICY "Financeiro consulta assinaturas"
  ON public.assinaturas_stripe
  FOR SELECT TO authenticated
  USING ((SELECT public.fretapp_gerencia_financeiro()));
