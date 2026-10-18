-- View novas:
-- 1 - Dicionário completo usando Natural Join
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

-- 2 - Interseção de traduções com mídia de áudio e imagem
DROP VIEW IF EXISTS organograma.vw_traducoes_audio_e_imagem CASCADE;
CREATE VIEW organograma.vw_traducoes_audio_e_imagem AS
SELECT id_traducao
FROM organograma.midias
WHERE tipo = 'audio'

INTERSECT

SELECT id_traducao
FROM organograma.midias
WHERE tipo = 'imagem';

-- 3 - Mostra as traduções com menos e mais consultas
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

-- 4 - Agrupa as categorias e filtra o resultado das funções de agregação por uma média mínima de clareza dos termos
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

-- 5 - Mapeia e identifica os termos do dicionário que possuem dados ou contextos ausentes ou nulos.
CREATE OR REPLACE VIEW organograma.vw_termos_com_dados_desconhecidos AS
SELECT
	t.id_traducao,
	tp.texto_portugues,
	ta.texto_akwe,
	COALESCE(ta.raiz_gramatical, 'UNKNOWN (Não informada)') AS raiz_gramatical,
	COALESCE(t.explicacao_contexto, 'UNKNOWN (Sem contexto)') AS
explicacao_contexto
FROM organograma.termos_traducoes t
JOIN organograma.termos_portugues tp ON t.id_termo_pt = tp.id_termo_pt
JOIN organograma.termos_akwe ta ON t.id_termo_akwe = ta.id_termo_akwe
WHERE t.explicacao_contexto IS NULL OR ta.raiz_gramatical IS NULL;

-- #region Views convencionais
DROP VIEW IF EXISTS organograma.vw_categorias_resumo CASCADE;
CREATE VIEW organograma.vw_categorias_resumo AS
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
    c.nome;

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

DROP VIEW IF EXISTS organograma.vw_estatisticas_detalhadas CASCADE;
CREATE VIEW organograma.vw_estatisticas_detalhadas AS
SELECT
    tt.id_traducao,
    tp.texto_portugues,
    ta.texto_akwe,
    e.quantidade_consultas,
    e.nivel_clareza,
    CASE 
        WHEN EXISTS (
            SELECT 1 
            FROM organograma.midias m 
            WHERE m.id_traducao = tt.id_traducao 
              AND m.tipo = 'audio'
        ) THEN COALESCE(e.reproducoes_audio, 0)
        ELSE NULL
    END AS reproducoes_audio,
	e.tempo_retencao_segundos
FROM organograma.termos_traducoes tt
INNER JOIN organograma.termos_portugues tp ON tp.id_termo_pt = tt.id_termo_pt
INNER JOIN organograma.termos_akwe ta ON ta.id_termo_akwe = tt.id_termo_akwe
LEFT JOIN organograma.estatisticas_termos e ON e.id_traducao = tt.id_traducao;

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

DROP VIEW IF EXISTS organograma.vw_tags_resumo_uso CASCADE;
CREATE VIEW organograma.vw_tags_resumo_uso AS
SELECT
	tg.id_tag,
	tg.nome AS nome_tag,
	COUNT(ttag.id_traducao) AS total_traducoes_associadas
FROM organograma.tags tg
LEFT JOIN organograma.termo_tags ttag ON tg.id_tag = ttag.id_tag
GROUP BY tg.id_tag, tg.nome;

DROP VIEW IF EXISTS organograma.vw_tags_traducoes_detalhada CASCADE;
CREATE VIEW organograma.vw_tags_traducoes_detalhada AS
SELECT
	tg.id_tag,
	tg.nome AS nome_tag,
	tt.id_traducao,
	tp.texto_portugues,
	ta.texto_akwe
FROM organograma.termos_traducoes tt
INNER JOIN organograma.termos_portugues tp ON tt.id_termo_pt = tp.id_termo_pt
INNER JOIN organograma.termos_akwe ta ON tt.id_termo_akwe = ta.id_termo_akwe
INNER JOIN organograma.termo_tags ttag ON tt.id_traducao = ttag.id_traducao
RIGHT JOIN organograma.tags tg ON ttag.id_tag = tg.id_tag;

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

DROP VIEW IF EXISTS organograma.vw_traducoes_com_tags CASCADE;
CREATE VIEW organograma.vw_traducoes_com_tags AS
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
    ta.texto_akwe;

DROP VIEW IF EXISTS organograma.vw_traducoes_sem_contexto CASCADE;
CREATE VIEW organograma.vw_traducoes_sem_contexto AS
SELECT
	tt.id_traducao,
	tp.id_termo_pt,
	tp.texto_portugues,
	ta.id_termo_akwe,
	ta.texto_akwe
FROM organograma.termos_traducoes tt
INNER JOIN organograma.termos_portugues tp ON tt.id_termo_pt = tp.id_termo_pt
INNER JOIN organograma.termos_akwe ta ON ta.id_termo_akwe = tt.id_termo_akwe
WHERE tt.explicacao_contexto IS NULL
	OR TRIM(tt.explicacao_contexto) = '';

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

-- #endregion

-- #region Materialized views

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

DROP MATERIALIZED VIEW IF EXISTS organograma.mv_dicionario_completo CASCADE;
CREATE MATERIALIZED VIEW organograma.mv_dicionario_completo AS
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
INNER JOIN organograma.categorias c ON tt.id_categoria = c.id_categoria
ORDER BY texto_portugues ASC;

DROP MATERIALIZED VIEW IF EXISTS organograma.mv_estatisticas_detalhadas CASCADE;
CREATE MATERIALIZED VIEW organograma.mv_estatisticas_detalhadas AS
SELECT
    tt.id_traducao,
    tp.texto_portugues,
    ta.texto_akwe,
    e.quantidade_consultas,
    e.nivel_clareza,
    CASE 
        WHEN EXISTS (
            SELECT 1 
            FROM organograma.midias m 
            WHERE m.id_traducao = tt.id_traducao 
              AND m.tipo = 'audio'
        ) THEN COALESCE(e.reproducoes_audio, 0)
        ELSE NULL
    END AS reproducoes_audiom,
	e.tempo_retencao_segundos
FROM organograma.termos_traducoes tt
INNER JOIN organograma.termos_portugues tp ON tp.id_termo_pt = tt.id_termo_pt
INNER JOIN organograma.termos_akwe ta ON ta.id_termo_akwe = tt.id_termo_akwe
LEFT JOIN organograma.estatisticas_termos e ON e.id_traducao = tt.id_traducao
ORDER BY tp.texto_portugues ASC;

DROP MATERIALIZED VIEW IF EXISTS organograma.mv_midias_por_tipo CASCADE;
CREATE MATERIALIZED VIEW organograma.mv_midias_por_tipo AS
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
INNER JOIN organograma.termos_akwe ta ON tt.id_termo_akwe = ta.id_termo_akwe
ORDER BY tp.texto_portugues ASC;

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

DROP MATERIALIZED VIEW IF EXISTS organograma.mv_tags_traducoes_detalhada CASCADE;
CREATE MATERIALIZED VIEW organograma.mv_tags_traducoes_detalhada AS
SELECT
	tg.id_tag,
	tg.nome AS nome_tag,
	tt.id_traducao,
	tp.texto_portugues,
	ta.texto_akwe
FROM organograma.termos_traducoes tt
INNER JOIN organograma.termos_portugues tp ON tt.id_termo_pt = tp.id_termo_pt
INNER JOIN organograma.termos_akwe ta ON tt.id_termo_akwe = ta.id_termo_akwe
INNER JOIN organograma.termo_tags ttag ON tt.id_traducao = ttag.id_traducao
RIGHT JOIN organograma.tags tg ON ttag.id_tag = tg.id_tag
ORDER BY texto_portugues ASC;

DROP MATERIALIZED VIEW IF EXISTS organograma.mv_traducoes_com_midias CASCADE;
CREATE MATERIALIZED VIEW organograma.mv_traducoes_com_midias AS
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
LEFT JOIN organograma.midias m ON m.id_traducao = tt.id_traducao
ORDER BY tp.texto_portugues ASC;

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

DROP MATERIALIZED VIEW IF EXISTS organograma.mv_traducoes_sem_contexto CASCADE;
CREATE MATERIALIZED VIEW organograma.mv_traducoes_sem_contexto AS
SELECT
	tt.id_traducao,
	tp.id_termo_pt,
	tp.texto_portugues,
	ta.id_termo_akwe,
	ta.texto_akwe
FROM organograma.termos_traducoes tt
INNER JOIN organograma.termos_portugues tp ON tt.id_termo_pt = tp.id_termo_pt
INNER JOIN organograma.termos_akwe ta ON ta.id_termo_akwe = tt.id_termo_akwe
WHERE tt.explicacao_contexto IS NULL
	OR TRIM(tt.explicacao_contexto) = ''
ORDER BY texto_portugues;

DROP MATERIALIZED VIEW IF EXISTS organograma.mv_traducoes_sem_midia CASCADE;
CREATE MATERIALIZED VIEW organograma.mv_traducoes_sem_midia AS
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
WHERE m.id_midia IS NULL
ORDER BY tp.texto_portugues ASC;

-- #endregion