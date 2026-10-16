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
