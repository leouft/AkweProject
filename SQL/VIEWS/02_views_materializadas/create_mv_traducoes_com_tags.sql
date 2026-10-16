DROP MATERIALIZED VIEW IF EXISTS organograma.mv_traducoes_com_tags CASCADE;
CREATE MATERIALIZED VIEW organograma.mv_traducoes_com_tags AS
SELECT 
    t.id_traducao,
    tp.texto_portugues,
    ta.texto_akwe,
    STRING_AGG(tg.nome, ', ') AS tags
FROM 
    organograma.termos_traducoes t
INNER JOIN organograma.termos_portugues tp ON tp.id_termo_pt = t.id_termo_pt
INNER JOIN organograma.termos_akwe ta ON ta.id_termo_akwe = t.id_termo_akwe
LEFT JOIN 
    organograma.termo_tags tt ON t.id_traducao = tt.id_traducao
LEFT JOIN 
    organograma.tags tg ON tt.id_tag = tg.id_tag
GROUP BY 
    t.id_traducao, 
    tp.texto_portugues, 
    ta.texto_akwe
ORDER BY texto_portugues ASC;