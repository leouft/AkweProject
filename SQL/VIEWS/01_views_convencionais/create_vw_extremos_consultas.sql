DROP VIEW IF EXISTS organograma.vw_extremos_consultas CASCADE;
CREATE VIEW organograma.vw_extremos_consultas AS
(
    SELECT
        et.id_traducao,
        'MÍNIMO' AS tipo,
        et.quantidade_consultas
    FROM organograma.estatisticas_termos AS et
    WHERE et.quantidade_consultas = (
        SELECT MIN(quantidade_consultas)
        FROM organograma.estatisticas_termos
    )
    ORDER BY et.id_traducao
    LIMIT 1
)

UNION ALL

(
    SELECT
        et.id_traducao,
        'MÁXIMO' AS tipo,
        et.quantidade_consultas
    FROM organograma.estatisticas_termos AS et
    WHERE et.quantidade_consultas = (
        SELECT MAX(quantidade_consultas)
        FROM organograma.estatisticas_termos
    )
    ORDER BY et.id_traducao
    LIMIT 1
);