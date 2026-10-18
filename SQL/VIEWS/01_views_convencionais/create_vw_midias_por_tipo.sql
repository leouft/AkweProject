DROP VIEW IF EXISTS organograma.vw_midias_por_tipo CASCADE;
CREATE VIEW organograma.vw_midias_por_tipo AS
SELECT 
    m.id_midia,
    m.tipo AS tipo_midia,
    m.url_arquivo,
    tt.id_traducao,
    tp.texto_portugues,
    ta.texto_akwe
FROM organograma.midias m
INNER JOIN organograma.termos_traducoes tt ON m.id_traducao = tt.id_traducao
INNER JOIN organograma.termos_portugues tp ON tt.id_termo_pt = tp.id_termo_pt
INNER JOIN organograma.termos_akwe ta ON tt.id_termo_akwe = ta.id_termo_akwe;