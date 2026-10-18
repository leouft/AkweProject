DROP MATERIALIZED VIEW IF EXISTS organograma.mv_categorias_resumo CASCADE;
CREATE MATERIALIZED VIEW organograma.mv_categorias_resumo AS
SELECT 
    c.id_categoria,            
    c.nome AS categoria_nome,  
    COUNT(tt.id_traducao) AS total_termos 
FROM 
    organograma.categorias c
LEFT JOIN 
    organograma.termos_traducoes tt ON c.id_categoria = tt.id_categoria
GROUP BY 
    c.id_categoria, 
    c.nome
ORDER BY total_termos DESC;