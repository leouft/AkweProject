SELECT
    texto_akwe AS termo_akwe,
    texto_portugues AS termo_portugues,
    nome_categoria AS categoria,
    CASE
        WHEN nome_categoria = 'Corpo Humano, Saúde e Anatomia'
            THEN 'Atenção Prioritária - Termos de Saúde'

        WHEN nome_categoria IN (
            'Fauna',
            'Flora, Plantas e Recursos Naturais',
            'Natureza, Geografia e Clima'
        )
            THEN 'Atenção Média - Termos de Natureza'

        ELSE 'Atenção Baixa - Vocabulário Geral'
    END AS prioridade
FROM organograma.vw_dicionario_completo;