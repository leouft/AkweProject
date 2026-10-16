DROP VIEW IF EXISTS organograma.vw_dicionario_completo_natural CASCADE;
CREATE VIEW organograma.vw_dicionario_completo_natural AS
SELECT
    id_traducao,
    texto_portugues,
    texto_akwe,
    raiz_gramatical,
    nome AS nome_categoria,
    explicacao_contexto
FROM organograma.termos_traducoes
NATURAL JOIN organograma.termos_portugues
NATURAL JOIN organograma.termos_akwe
NATURAL JOIN organograma.categorias;