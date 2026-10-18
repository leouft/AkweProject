SELECT
	t.id_traducao,
	tp.texto_portugues,
	ta.texto_akwe,
	e.reproducoes_audio
FROM organograma.termos_traducoes t
JOIN organograma.termos_portugues tp ON t.id_termo_pt = tp.id_termo_pt
JOIN organograma.termos_akwe ta ON t.id_termo_akwe = ta.id_termo_akwe
JOIN organograma.estatisticas_termos e ON t.id_traducao = e.id_traducao
WHERE e.reproducoes_audio > SOME (
	SELECT e2.reproducoes_audio
	FROM organograma.termos_traducoes t2
	JOIN organograma.estatisticas_termos e2 ON t2.id_traducao = e2.id_traducao
	WHERE t2.id_categoria = 1
);