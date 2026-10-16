DROP VIEW IF EXISTS organograma.vw_traducoes_audio_e_imagem CASCADE;
CREATE VIEW organograma.vw_traducoes_audio_e_imagem AS
SELECT id_traducao
FROM organograma.midias
WHERE tipo = 'audio'

INTERSECT

SELECT id_traducao
FROM organograma.midias
WHERE tipo = 'imagem';