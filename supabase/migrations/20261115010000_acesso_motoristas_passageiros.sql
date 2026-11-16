-- FretApp - contas de acesso criadas pelo administrador.
--
-- O administrador cadastra o motorista/passageiro e cria o login dele pela
-- Edge Function `criar-acesso` (que usa a service_role). A função:
--   1. cria o usuário no Supabase Auth com e-mail e senha provisória;
--   2. cria a linha em public.perfis com o tipo certo (motorista/passageiro);
--   3. grava o id da conta em perfil_id do cadastro.
-- Ao entrar, a HomeView lê perfis.tipo e abre a tela correspondente.
--
-- Execute no SQL Editor do Supabase antes de usar "Criar acesso ao app".

-- Motoristas: a coluna já existe na migration 20261112060000_viagem_do_dia.sql;
-- repetida aqui (IF NOT EXISTS) para não depender da ordem de execução.
ALTER TABLE public.motoristas
  ADD COLUMN IF NOT EXISTS perfil_id uuid UNIQUE
    REFERENCES public.perfis(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.motoristas.perfil_id IS
  'Conta de login (perfis.id) usada por este motorista no app.';

ALTER TABLE public.passageiros
  ADD COLUMN IF NOT EXISTS perfil_id uuid UNIQUE
    REFERENCES public.perfis(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.passageiros.perfil_id IS
  'Conta de login (perfis.id) usada por este passageiro no app.';

-- O vínculo só é gravado pela Edge Function (service_role). O administrador
-- continua editando os demais campos do cadastro pelo app, mas não consegue
-- apontar um cadastro para a conta de outra pessoa.
--
-- (Um REVOKE UPDATE (perfil_id) não bastaria: a tabela inteira já tem
-- GRANT UPDATE para authenticated, e o privilégio de tabela prevalece.)
CREATE OR REPLACE FUNCTION public.fretapp_proteger_perfil_id()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  -- Requisições do app rodam como authenticated/anon. A Edge Function
  -- (service_role) e o ON DELETE SET NULL (dono da tabela) passam direto.
  IF current_user IN ('authenticated', 'anon') THEN
    IF TG_OP = 'INSERT' AND NEW.perfil_id IS NOT NULL THEN
      RAISE EXCEPTION 'perfil_id é definido apenas pela criação de acesso.'
        USING ERRCODE = '42501';
    END IF;
    IF TG_OP = 'UPDATE' AND NEW.perfil_id IS DISTINCT FROM OLD.perfil_id THEN
      RAISE EXCEPTION 'perfil_id é definido apenas pela criação de acesso.'
        USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS motoristas_proteger_perfil_id ON public.motoristas;
CREATE TRIGGER motoristas_proteger_perfil_id
  BEFORE INSERT OR UPDATE ON public.motoristas
  FOR EACH ROW EXECUTE FUNCTION public.fretapp_proteger_perfil_id();

DROP TRIGGER IF EXISTS passageiros_proteger_perfil_id ON public.passageiros;
CREATE TRIGGER passageiros_proteger_perfil_id
  BEFORE INSERT OR UPDATE ON public.passageiros
  FOR EACH ROW EXECUTE FUNCTION public.fretapp_proteger_perfil_id();
