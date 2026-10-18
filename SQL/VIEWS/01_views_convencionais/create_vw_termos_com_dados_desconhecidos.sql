CREATE OR REPLACE VIEW organograma.vw_termos_com_dados_desconhecidos AS
SELECT
	t.id_traducao,
	tp.texto_portugues,
	ta.texto_akwe,
	COALESCE(ta.raiz_gramatical, 'UNKNOWN (Não informada)') AS raiz_gramatical,
	COALESCE(t.explicacao_contexto, 'UNKNOWN (Sem contexto)') AS
explicacao_contexto
FROM organograma.termos_traducoes t
JOIN organograma.termos_portugues tp ON t.id_termo_pt = tp.id_termo_pt
JOIN organograma.termos_akwe ta ON t.id_termo_akwe = ta.id_termo_akwe
WHERE t.explicacao_contexto IS NULL OR ta.raiz_gramatical IS NULL;