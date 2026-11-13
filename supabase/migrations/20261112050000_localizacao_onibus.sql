-- FretApp - posição do ônibus em tempo real.
--
-- O motorista grava a própria posição enquanto a viagem está em andamento;
-- passageiros e administradores só leem, e só enquanto em_viagem = true.
-- Ao finalizar, o app marca em_viagem = false e a posição deixa de ser visível.

CREATE TABLE IF NOT EXISTS public.localizacao_onibus (
  motorista_id uuid PRIMARY KEY
    REFERENCES public.perfis(id) ON DELETE CASCADE,
  latitude double precision NOT NULL CHECK (latitude BETWEEN -90 AND 90),
  longitude double precision NOT NULL CHECK (longitude BETWEEN -180 AND 180),
  rumo double precision CHECK (rumo IS NULL OR (rumo >= 0 AND rumo < 360)),
  precisao double precision CHECK (precisao IS NULL OR precisao >= 0),
  em_viagem boolean NOT NULL DEFAULT false,
  atualizado_em timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.localizacao_onibus ENABLE ROW LEVEL SECURITY;

-- Motorista grava/atualiza só a própria linha.
DROP POLICY IF EXISTS "Motorista grava propria localizacao"
  ON public.localizacao_onibus;
CREATE POLICY "Motorista grava propria localizacao"
  ON public.localizacao_onibus
  FOR INSERT TO authenticated
  WITH CHECK (
    motorista_id = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.perfis p
      WHERE p.id = (SELECT auth.uid()) AND LOWER(p.tipo) = 'motorista'
    )
  );

DROP POLICY IF EXISTS "Motorista atualiza propria localizacao"
  ON public.localizacao_onibus;
CREATE POLICY "Motorista atualiza propria localizacao"
  ON public.localizacao_onibus
  FOR UPDATE TO authenticated
  USING (motorista_id = (SELECT auth.uid()))
  WITH CHECK (motorista_id = (SELECT auth.uid()));

-- Leitura: o próprio motorista sempre; passageiros/admin só em viagem.
DROP POLICY IF EXISTS "Consulta localizacao do onibus em viagem"
  ON public.localizacao_onibus;
CREATE POLICY "Consulta localizacao do onibus em viagem"
  ON public.localizacao_onibus
  FOR SELECT TO authenticated
  USING (
    motorista_id = (SELECT auth.uid())
    OR (
      em_viagem
      AND EXISTS (
        SELECT 1 FROM public.perfis p
        WHERE p.id = (SELECT auth.uid())
          AND LOWER(p.tipo) IN ('passageiro', 'administrador', 'admin')
      )
    )
  );

GRANT SELECT, INSERT, UPDATE ON public.localizacao_onibus TO authenticated;

-- Realtime: o passageiro recebe cada atualização sem recarregar.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'localizacao_onibus'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.localizacao_onibus;
  END IF;
END $$;
