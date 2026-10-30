-- Função que será chamada no trigger

CREATE OR REPLACE FUNCTION organograma.atualizar_timestamp_usuario()
RETURNS TRIGGER AS $$
BEGIN
    NEW.atualizado_em = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger
CREATE TRIGGER trg_usuarios_update
    BEFORE UPDATE ON organograma.usuarios
    FOR EACH ROW
	WHEN (OLD.* IS DISTINCT FROM NEW.*)
    EXECUTE FUNCTION organograma.atualizar_timestamp_usuario();


-- 1. Função limpa para atualizar o timestamp da própria tradução (Sem loop!)
CREATE OR REPLACE FUNCTION organograma.fn_atualizar_proprio_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.atualizado_em = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Função para propagar a alteração de tabelas filhas/relacionadas para a tradução
CREATE OR REPLACE FUNCTION organograma.fn_propagar_para_traducao_direta()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE organograma.termos_traducoes
    SET atualizado_em = CURRENT_TIMESTAMP
    WHERE id_traducao = COALESCE(NEW.id_traducao, OLD.id_traducao);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Função para propagar alterações via Tag
CREATE OR REPLACE FUNCTION organograma.fn_propagar_para_traducao_por_tag()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE organograma.termos_traducoes
    SET atualizado_em = CURRENT_TIMESTAMP
    WHERE id_traducao IN (
        SELECT id_traducao FROM organograma.termo_tags 
        WHERE id_tag = COALESCE(NEW.id_tag, OLD.id_tag)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Função para propagar alterações via Termo Português
CREATE OR REPLACE FUNCTION organograma.fn_propagar_para_traducao_por_pt()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE organograma.termos_traducoes
    SET atualizado_em = CURRENT_TIMESTAMP
    WHERE id_termo_pt = NEW.id_termo_pt;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Função para propagar alterações via Termo Akwẽ
CREATE OR REPLACE FUNCTION organograma.fn_propagar_para_traducao_por_akwe()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE organograma.termos_traducoes
    SET atualizado_em = CURRENT_TIMESTAMP
    WHERE id_termo_akwe = NEW.id_termo_akwe;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 6. Função para propagar alterações via Categoria
CREATE OR REPLACE FUNCTION organograma.fn_propagar_para_traducao_por_categoria()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE organograma.termos_traducoes
    SET atualizado_em = CURRENT_TIMESTAMP
    WHERE id_categoria = COALESCE(NEW.id_categoria, OLD.id_categoria);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- =========================================================
-- APLICAÇÃO DOS TRIGGERS NAS TABELAS
-- =========================================================

-- Termos Traducoes (Atualização direta na própria tabela)
DROP TRIGGER IF EXISTS tr_traducao_mudanca ON organograma.termos_traducoes;
CREATE TRIGGER tr_traducao_mudanca
BEFORE UPDATE ON organograma.termos_traducoes
FOR EACH ROW EXECUTE FUNCTION organograma.fn_atualizar_proprio_timestamp();

-- Estatisticas Termos
DROP TRIGGER IF EXISTS tr_estatisticas_mudanca ON organograma.estatisticas_termos;
CREATE TRIGGER tr_estatisticas_mudanca
AFTER INSERT OR UPDATE ON organograma.estatisticas_termos
FOR EACH ROW EXECUTE FUNCTION organograma.fn_propagar_para_traducao_direta();

-- Midias
DROP TRIGGER IF EXISTS tr_midias_mudanca ON organograma.midias;
CREATE TRIGGER tr_midias_mudanca
AFTER INSERT OR UPDATE OR DELETE ON organograma.midias
FOR EACH ROW EXECUTE FUNCTION organograma.fn_propagar_para_traducao_direta();

-- Termo Tags
DROP TRIGGER IF EXISTS tr_termo_tags_mudanca ON organograma.termo_tags;
CREATE TRIGGER tr_termo_tags_mudanca
AFTER INSERT OR DELETE ON organograma.termo_tags
FOR EACH ROW EXECUTE FUNCTION organograma.fn_propagar_para_traducao_por_tag();

-- Tags
DROP TRIGGER IF EXISTS tr_tags_mudanca ON organograma.tags;
CREATE TRIGGER tr_tags_mudanca
AFTER UPDATE ON organograma.tags
FOR EACH ROW EXECUTE FUNCTION organograma.fn_propagar_para_traducao_por_tag();

-- Termos Portugues
DROP TRIGGER IF EXISTS tr_termo_pt_mudanca ON organograma.termos_portugues;
CREATE TRIGGER tr_termo_pt_mudanca
AFTER UPDATE ON organograma.termos_portugues
FOR EACH ROW EXECUTE FUNCTION organograma.fn_propagar_para_traducao_por_pt();

-- Termos Akwe
DROP TRIGGER IF EXISTS tr_termo_akwe_mudanca ON organograma.termos_akwe;
CREATE TRIGGER tr_termo_akwe_mudanca
AFTER UPDATE ON organograma.termos_akwe
FOR EACH ROW EXECUTE FUNCTION organograma.fn_propagar_para_traducao_por_akwe();

-- Categorias
DROP TRIGGER IF EXISTS tr_categorias_mudanca ON organograma.categorias;
CREATE TRIGGER tr_categorias_mudanca
AFTER UPDATE ON organograma.categorias
FOR EACH ROW EXECUTE FUNCTION organograma.fn_propagar_para_traducao_por_categoria();