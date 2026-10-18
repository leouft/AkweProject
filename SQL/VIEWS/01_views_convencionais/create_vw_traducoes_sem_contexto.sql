DROP VIEW IF EXISTS organograma.vw_traducoes_sem_contexto CASCADE;
CREATE VIEW organograma.vw_traducoes_sem_contexto AS
SELECT
	tt.id_traducao,
	tp.id_termo_pt,
	tp.texto_portugues,
	ta.id_termo_akwe,
	ta.texto_akwe
FROM organograma.termos_traducoes tt
INNER JOIN organograma.termos_portugues tp ON tt.id_termo_pt = tp.id_termo_pt
INNER JOIN organograma.termos_akwe ta ON ta.id_termo_akwe = tt.id_termo_akwe
WHERE tt.explicacao_contexto IS NULL
	OR TRIM(tt.explicacao_contexto) = '';