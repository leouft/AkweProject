TRUNCATE TABLE organograma.categorias RESTART IDENTITY CASCADE;

INSERT INTO organograma.categorias(id_categoria, nome)
VALUES
(1, 'Corpo Humano, Saúde e Anatomia'),
(2, 'Fauna'),
(3, 'Flora, Plantas e Recursos Naturais'),
(4, 'Ações, Acontecimentos e Processos'),
(5, 'Objetos, Ferramentas e Materialidade'),
(6, 'Gramática e Conectivos Básicos'),
(7, 'Qualidades, Formas e Propriedades'),
(8, 'Natureza, Geografia e Clima'),
(9, 'Cultura, Rituais e Sociedade'),
(10, 'Culinária, Preparo e Alimentos Processados');

SELECT * 
FROM organograma.categorias