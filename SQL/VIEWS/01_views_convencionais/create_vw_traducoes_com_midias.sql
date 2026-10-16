DROP VIEW IF EXISTS organograma.vw_traducoes_com_midias CASCADE;
CREATE VIEW organograma.vw_traducoes_com_midias AS
SELECT 
    tt.id_traducao,
    tp.texto_portugues,
    ta.texto_akwe,
    m.id_midia,
    m.tipo AS tipo_midia,
    m.url_arquivo
FROM organograma.termos_traducoes tt
INNER JOIN organograma.termos_portugues tp ON tp.id_termo_pt = tt.id_termo_pt
INNER JOIN organograma.termos_akwe ta ON ta.id_termo_akwe = tt.id_termo_akwe
LEFT JOIN organograma.midias m ON m.id_traducao = tt.id_traducao;