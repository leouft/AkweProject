CREATE OR REPLACE VIEW organograma.vw_categorias_por_clareza AS
SELECT
	c.nome AS categoria,
	COUNT(t.id_traducao) AS total_termos,
	ROUND(AVG(e.nivel_clareza), 2) AS media_clareza
FROM organograma.categorias c
JOIN organograma.termos_traducoes t USING (id_categoria)
LEFT JOIN organograma.estatisticas_termos e USING (id_traducao)
GROUP BY c.id_categoria, c.nome
HAVING AVG(e.nivel_clareza) >= 3.0; -- Filtra grupos após a agregação