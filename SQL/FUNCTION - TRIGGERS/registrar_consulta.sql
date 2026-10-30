CREATE OR REPLACE FUNCTION public.registrar_consulta(id_palavra INT)
RETURNS INT AS $$
	UPDATE public.estatisticas_termos
	SET quantidade_consultas = quantidade_consultas + 1
	WHERE id_traducao = id_palavra
	RETURNING id_estatistica;
$$ LANGUAGE SQL;