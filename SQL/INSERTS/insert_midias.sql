TRUNCATE TABLE organograma.midias RESTART IDENTITY CASCADE;
INSERT INTO organograma.midias(tipo, url_arquivo, id_traducao)
VALUES
	('audio', '/midias/audio/kra.mp3', 709),
	('audio', '/midias/audio/di.mp3', 16),
	('audio', '/midias/audio/nmizu.mp3', 297),
	('imagem', '/midias/imagem/nmizu.webp', 297),
	('imagem', '/midias/imagem/di.webp', 16);