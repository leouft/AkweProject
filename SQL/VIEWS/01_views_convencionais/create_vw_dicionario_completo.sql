DROP VIEW IF EXISTS organograma.vw_dicionario_completo CASCADE;
CREATE VIEW organograma.vw_dicionario_completo AS
SELECT 
	tt.id_traducao,
	tp.texto_portugues,
	ta.texto_akwe,
	ta.raiz_gramatical,
	c.nome AS nome_categoria,
	tt.explicacao_contexto
FROM organograma.termos_traducoes tt
INNER JOIN organograma.termos_portugues tp ON tp.id_termo_pt = tt.id_termo_pt
INNER JOIN organograma.termos_akwe ta ON ta.id_termo_akwe = tt.id_termo_akwe
INNER JOIN organograma.categorias c ON tt.id_categoria = c.id_categoria;