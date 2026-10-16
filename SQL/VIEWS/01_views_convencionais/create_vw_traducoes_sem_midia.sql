DROP VIEW IF EXISTS organograma.vw_traducoes_sem_midia CASCADE;
CREATE VIEW organograma.vw_traducoes_sem_midia AS
SELECT
    tt.id_traducao,
    tp.id_termo_pt,
    tp.texto_portugues,
    ta.id_termo_akwe,
    ta.texto_akwe
FROM organograma.termos_traducoes tt
INNER JOIN organograma.termos_portugues tp ON tp.id_termo_pt = tt.id_termo_pt
INNER JOIN organograma.termos_akwe ta ON ta.id_termo_akwe = tt.id_termo_akwe
LEFT JOIN organograma.midias m ON m.id_traducao = tt.id_traducao
WHERE m.id_midia IS NULL;