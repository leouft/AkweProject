DELETE FROM organograma.usuarios;
ALTER SEQUENCE organograma.usuarios_id_usuario_seq RESTART WITH 1;
INSERT INTO organograma.usuarios (
    username,
    email,
    senha_hash,
    perfil,
    ativo
)
VALUES (
    'leo',
    'leonardo.soares1@mail.uft.edu.br',
    '$argon2id$v=19$m=65536,t=3,p=4$TuUzNOj5w7QQKADds41Wcw$T4KFG0FbpRAKTTVBwZ3yGeCXChZGkBFJqTTpnXimOLM',
    'admin',
    TRUE
);