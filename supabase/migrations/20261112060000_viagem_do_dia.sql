-- FretApp - viagem do dia para motorista e passageiro, com mapa.
--
-- 1. Coordenadas nos pontos e trajeto (linha do mapa) na rota.
-- 2. viagem_do_dia(): a viagem programada de hoje com rota, veículo e pontos.
--    O RLS não deixa motorista/passageiro lerem pontos_rota e veiculos, então
--    a função devolve só o necessário para a tela.
-- 3. atualizar_status_viagem(): o motorista marca a PRÓPRIA viagem como
--    em andamento / finalizada (o RLS de viagens só permite admin editar).

ALTER TABLE public.pontos_rota
  ADD COLUMN IF NOT EXISTS latitude double precision
    CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
  ADD COLUMN IF NOT EXISTS longitude double precision
    CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180);

ALTER TABLE public.rotas
  ADD COLUMN IF NOT EXISTS trajeto jsonb,
  ADD COLUMN IF NOT EXISTS distancia_km numeric(6, 1),
  ADD COLUMN IF NOT EXISTS duracao_min integer;

COMMENT ON COLUMN public.rotas.trajeto IS
  'Linha do trajeto no mapa: array de [latitude, longitude].';

-- Vínculo entre o cadastro do motorista (tela do administrador, com CNH) e a
-- conta de login dele (perfis). rotas.motorista_id aponta para motoristas;
-- viagens.motorista_id aponta para perfis — este campo liga os dois.
ALTER TABLE public.motoristas
  ADD COLUMN IF NOT EXISTS perfil_id uuid UNIQUE
    REFERENCES public.perfis(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.motoristas.perfil_id IS
  'Conta de login (perfis.id) usada por este motorista no app.';

-- ── viagem_do_dia ───────────────────────────────────────────────────────────
-- Motorista: a próxima viagem DELE (programada ou em andamento) a partir de
-- hoje. Passageiro/admin: a próxima viagem do dia.
CREATE OR REPLACE FUNCTION public.viagem_do_dia()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  WITH eu AS (
    SELECT p.id, LOWER(p.tipo) AS tipo
    FROM public.perfis p
    WHERE p.id = (SELECT auth.uid())
  ),
  inicio_hoje AS (
    SELECT (date_trunc('day', now() AT TIME ZONE 'America/Sao_Paulo'))
             AT TIME ZONE 'America/Sao_Paulo' AS t
  ),
  v AS (
    SELECT vg.*
    FROM public.viagens vg, eu, inicio_hoje
    WHERE vg.status IN ('programada', 'em_andamento')
      AND vg.saida_prevista >= inicio_hoje.t
      AND (eu.tipo <> 'motorista' OR vg.motorista_id = eu.id)
    ORDER BY (vg.status = 'em_andamento') DESC, vg.saida_prevista
    LIMIT 1
  )
  SELECT jsonb_build_object(
    'id', v.id,
    'status', v.status,
    'saida_prevista', v.saida_prevista,
    'chegada_prevista', v.chegada_prevista,
    'saida_real', v.saida_real,
    'rota', jsonb_build_object(
      'nome', r.nome,
      'origem', r.origem,
      'destino', r.destino,
      'trajeto', r.trajeto,
      'distancia_km', r.distancia_km,
      'duracao_min', r.duracao_min
    ),
    'veiculo', CASE WHEN ve.id IS NULL THEN NULL ELSE jsonb_build_object(
      'placa', ve.placa,
      'modelo', ve.modelo,
      'capacidade', ve.capacidade
    ) END,
    'pontos', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'nome', pr.nome,
        'endereco', pr.endereco,
        'horario', pr.horario,
        'ordem', pr.ordem,
        'latitude', pr.latitude,
        'longitude', pr.longitude
      ) ORDER BY pr.ordem)
      FROM public.pontos_rota pr
      WHERE pr.rota_id = r.id
    ), '[]'::jsonb)
  )
  FROM v
  JOIN public.rotas r ON r.id = v.rota_id
  LEFT JOIN public.veiculos ve ON ve.id = v.veiculo_id
  WHERE EXISTS (SELECT 1 FROM eu);
$$;

REVOKE ALL ON FUNCTION public.viagem_do_dia() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.viagem_do_dia() TO authenticated;

-- ── atualizar_status_viagem ─────────────────────────────────────────────────
-- Só o motorista da viagem; só programada -> em_andamento -> finalizada.
CREATE OR REPLACE FUNCTION public.atualizar_status_viagem(
  p_viagem uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  atual text;
BEGIN
  SELECT status INTO atual
  FROM public.viagens
  WHERE id = p_viagem AND motorista_id = (SELECT auth.uid())
  FOR UPDATE;

  IF atual IS NULL THEN
    RAISE EXCEPTION 'Viagem não encontrada para este motorista.'
      USING ERRCODE = '42501';
  END IF;

  IF p_status = 'em_andamento' AND atual = 'programada' THEN
    UPDATE public.viagens
      SET status = 'em_andamento', saida_real = now()
      WHERE id = p_viagem;
  ELSIF p_status = 'finalizada' AND atual = 'em_andamento' THEN
    UPDATE public.viagens
      SET status = 'finalizada', chegada_real = now()
      WHERE id = p_viagem;
  ELSIF p_status IS DISTINCT FROM atual THEN
    RAISE EXCEPTION 'Mudança de status inválida: % -> %', atual, p_status
      USING ERRCODE = '22023';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.atualizar_status_viagem(uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.atualizar_status_viagem(uuid, text)
  TO authenticated;
