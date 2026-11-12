-- FretApp - complemento do gerenciamento administrativo de viagens.
-- A tabela public.viagens já existe no schema do projeto.
-- Esta migration preserva sua estrutura e apenas adiciona o necessário.

ALTER TABLE public.viagens
  ADD COLUMN IF NOT EXISTS observacoes TEXT;

CREATE TABLE IF NOT EXISTS public.viagem_passageiros (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  viagem_id UUID NOT NULL
    REFERENCES public.viagens(id) ON DELETE CASCADE,
  passageiro_id UUID NOT NULL
    REFERENCES public.passageiros(id) ON DELETE RESTRICT,
  ponto_embarque_id UUID
    REFERENCES public.pontos_rota(id) ON DELETE SET NULL,
  embarcou BOOLEAN NOT NULL DEFAULT FALSE,
  horario_embarque TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT viagem_passageiros_unicos
    UNIQUE (viagem_id, passageiro_id)
);

CREATE INDEX IF NOT EXISTS idx_viagens_data_status
  ON public.viagens (saida_prevista, status);
CREATE INDEX IF NOT EXISTS idx_viagem_passageiros_viagem
  ON public.viagem_passageiros (viagem_id);
CREATE INDEX IF NOT EXISTS idx_viagem_passageiros_passageiro
  ON public.viagem_passageiros (passageiro_id);

ALTER TABLE public.viagem_passageiros ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Administradores gerenciam passageiros das viagens"
  ON public.viagem_passageiros;

CREATE POLICY "Administradores gerenciam passageiros das viagens"
  ON public.viagem_passageiros
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.perfis p
      WHERE p.id = (SELECT auth.uid())
        AND LOWER(p.tipo) IN ('admin', 'administrador')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.perfis p
      WHERE p.id = (SELECT auth.uid())
        AND LOWER(p.tipo) IN ('admin', 'administrador')
    )
  );

GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.viagem_passageiros TO authenticated;
