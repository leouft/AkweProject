DROP VIEW IF EXISTS organograma.vw_tags_traducoes_detalhada CASCADE;
CREATE VIEW organograma.vw_tags_traducoes_detalhada AS
SELECT
	tg.id_tag,
	tg.nome AS nome_tag,
	tt.id_traducao,
	tp.texto_portugues,
	ta.texto_akwe
FROM organograma.termos_traducoes tt
INNER JOIN organograma.termos_portugues tp ON tt.id_termo_pt = tp.id_termo_pt
INNER JOIN organograma.termos_akwe ta ON tt.id_termo_akwe = ta.id_termo_akwe
INNER JOIN organograma.termo_tags ttag ON tt.id_traducao = ttag.id_traducao
RIGHT JOIN organograma.tags tg ON ttag.id_tag = tg.id_tag;