-- FretApp - lista do motorista a partir da enquete de presença do dia.
--
-- Pelas políticas atuais, o motorista não consegue ler confirmacoes_presenca
-- nem os perfis dos passageiros. Esta função devolve SOMENTE o necessário
-- para a lista de embarque (id, nome e trajeto) de quem vai comparecer,
-- e só para quem é motorista ou administrador.

CREATE OR REPLACE FUNCTION public.passageiros_enquete_dia(p_data date)
RETURNS TABLE (passageiro_id uuid, nome text, trajeto text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    c.passageiro_id,
    COALESCE(NULLIF(btrim(p.nome_completo), ''), 'Passageiro') AS nome,
    COALESCE(
      c.trajeto,
      CASE WHEN c.vai_comparecer THEN 'ida_volta' ELSE 'nao_vai' END
    ) AS trajeto
  FROM public.confirmacoes_presenca c
  JOIN public.perfis p ON p.id = c.passageiro_id
  WHERE c.data = p_data
    AND COALESCE(
      c.trajeto,
      CASE WHEN c.vai_comparecer THEN 'ida_volta' ELSE 'nao_vai' END
    ) <> 'nao_vai'
    AND EXISTS (
      SELECT 1
      FROM public.perfis eu
      WHERE eu.id = (SELECT auth.uid())
        AND LOWER(eu.tipo) IN ('motorista', 'administrador', 'admin')
    )
  ORDER BY 2;
$$;

REVOKE ALL ON FUNCTION public.passageiros_enquete_dia(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.passageiros_enquete_dia(date) TO authenticated;
