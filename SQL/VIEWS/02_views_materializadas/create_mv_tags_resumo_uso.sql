DROP MATERIALIZED VIEW IF EXISTS organograma.mv_tags_resumo_uso CASCADE;
CREATE MATERIALIZED VIEW organograma.mv_tags_resumo_uso AS
SELECT
	tg.id_tag,
	tg.nome AS nome_tag,
	COUNT(ttag.id_traducao) AS total_traducoes_associadas
FROM organograma.tags tg
LEFT JOIN organograma.termo_tags ttag ON tg.id_tag = ttag.id_tag
GROUP BY tg.id_tag, tg.nome
ORDER BY total_traducoes_associadas DESC;