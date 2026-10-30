CREATE SCHEMA IF NOT EXISTS public;

-- 1. Remoção preventiva (Drop Cascade na ordem inversa de dependência)
DROP TABLE IF EXISTS public.termo_tags CASCADE;
DROP TABLE IF EXISTS public.estatisticas_termos CASCADE;
DROP TABLE IF EXISTS public.midias CASCADE;
DROP TABLE IF EXISTS public.tags CASCADE;
DROP TABLE IF EXISTS public.termos_traducoes CASCADE;
DROP TABLE IF EXISTS public.termos_akwe CASCADE;
DROP TABLE IF EXISTS public.termos_portugues CASCADE;
DROP TABLE IF EXISTS public.categorias CASCADE;

-- 2. Categorias (Tabela 1)
CREATE TABLE public.categorias (
	id_categoria SERIAL PRIMARY KEY,
	nome VARCHAR(128) NOT NULL UNIQUE
);

-- 3. Vocabulário em Português (Tabela 2)
CREATE TABLE public.termos_portugues (
	id_termo_pt SERIAL PRIMARY KEY,
	texto_portugues VARCHAR(128) NOT NULL UNIQUE
);

-- Vocabulário em Akwẽ (Tabela 3)
CREATE TABLE public.termos_akwe (
	id_termo_akwe SERIAL PRIMARY KEY,
	texto_akwe VARCHAR(128) NOT NULL UNIQUE,
	raiz_gramatical VARCHAR(50)
);

-- 5. Traduções e Vínculos (Tabela 4 - Conecta PT + Akwẽ + Categoria)
CREATE TABLE public.termos_traducoes (
	id_traducao SERIAL PRIMARY KEY,
	id_termo_pt INT NOT NULL REFERENCES public.termos_portugues(id_termo_pt),
	id_termo_akwe INT NOT NULL REFERENCES public.termos_akwe(id_termo_akwe),
	id_categoria INT NOT NULL REFERENCES public.categorias(id_categoria),
	explicacao_contexto TEXT,
	atualizado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 6. Mídias (Tabela 5 - Áudios e Imagens da tradução)
CREATE TABLE public.midias (
	id_midia SERIAL PRIMARY KEY,
	tipo VARCHAR(15) NOT NULL,
	url_arquivo VARCHAR(255) NOT NULL,
	id_traducao INT NOT NULL REFERENCES public.termos_traducoes(id_traducao)
);

-- 7. Tags (Tabela 6)
CREATE TABLE public.tags (
	id_tag SERIAL PRIMARY KEY,
	nome VARCHAR(64) NOT NULL UNIQUE
);

-- 8. Termo_Tags (Tabela 7 - Intermediária N:M ligando Tradução e Tags)
CREATE TABLE public.termo_tags (
	id_traducao INT NOT NULL REFERENCES public.termos_traducoes(id_traducao),
	id_tag INT NOT NULL REFERENCES public.tags(id_tag),
	CONSTRAINT pk_termo_tags PRIMARY KEY (id_traducao, id_tag)
);

-- 9. Estatísticas de Uso (Tabela 8 - Dados numéricos para o professor)
CREATE TABLE public.estatisticas_termos (
	id_estatistica SERIAL PRIMARY KEY,
	id_traducao INT NOT NULL UNIQUE REFERENCES public.termos_traducoes(id_traducao),
	quantidade_consultas INT DEFAULT 0,
	reproducoes_audio INT DEFAULT 0,
	nivel_clareza INT CHECK (nivel_clareza BETWEEN 1 AND 5),
	tempo_retencao_segundos INT DEFAULT 0
);

-- 10. Cria tabela de usuários

DROP TABLE IF EXISTS public.usuarios;

CREATE TABLE IF NOT EXISTS public.usuarios (
    id_usuario SERIAL PRIMARY KEY,

    username VARCHAR(100) NOT NULL UNIQUE,

    email VARCHAR(255) UNIQUE,

    senha_hash TEXT NOT NULL,

    perfil VARCHAR(20) NOT NULL DEFAULT 'leitor'
        CHECK (perfil IN ('admin', 'leitor')),

    ativo BOOLEAN NOT NULL DEFAULT TRUE,

    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    atualizado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);