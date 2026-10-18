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