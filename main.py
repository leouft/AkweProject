import os
from dotenv import load_dotenv
import pyodbc
from fastapi import FastAPI, Query, HTTPException
from typing import Optional
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware

# Carrega o .env
load_dotenv()
DATABASE_LOGIN = os.getenv("DATABASE_LOGIN")
DATABASE_PASSWORD = os.getenv("DATABASE_PASSWORD")

# Cria o objeto fastapi
app = FastAPI(
    title="API",
    description="Backend"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permite requisições de qualquer origem para testes
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Monta a string ODBC usando f-string
CONEXAO_ODBC = (
    f"DRIVER={{PostgreSQL Unicode}};"
    f"SERVER=localhost;"
    f"PORT=5432;"
    f"DATABASE=db_akwe;"
    f"UID={DATABASE_LOGIN};"
    f"PWD={DATABASE_PASSWORD};"
)

# region Schemas pra ser passados como argumento nas rotas

class TraducaoCreateSchema(BaseModel):
    texto_portugues: str
    texto_akwe: str
    raiz_gramatical: Optional[str] = None
    id_categoria: int
    explicacao_contexto: Optional[str] = None

class TraducaoUpdateSchema(BaseModel):
    id_traducao: int
    id_categoria: int
    explicacao_contexto: Optional[str] = None

class TermoAkweCreateSchema(BaseModel):
    texto_akwe: str
    raiz_gramatical: Optional[str] = None

class TermoTagsSchema(BaseModel):
    id_traducao: int
    id_tag: int

class MidiaCreateSchema(BaseModel):
    tipo: str
    url_arquivo: str
    id_traducao: int

class CategoriaUpdateSchema(BaseModel):
    id_categoria: int
    nome: str

class EstatisticasUpdateSchema(BaseModel):
    id_estatistica: int
    id_traducao: int
    quantidade_consultas: int
    reproducoes_audio: int
    nivel_clareza: int
    tempo_retencao_segundos: int

class MidiaUpdateSchema(BaseModel):
    id_midia: int
    tipo: str
    url_arquivo: str
    id_traducao: int

class TagUpdateSchema(BaseModel):
    id_tag: int
    nome: str

class TermoAkweUpdateSchema(BaseModel):
    id_termo_akwe: int
    texto_akwe: str
    raiz_gramatical: Optional[str] = None

class TermoPtUpdateSchema(BaseModel):
    id_termo_pt: int
    texto_portugues: str

# endregion

# Função que executa um query SQL

def executar_query(query: str, params: tuple = (), fetch_all: bool = True):
    """Abre conexão ODBC, executa a SQL pura, confirma a transação e fecha o cursor."""
    try:
        conn = pyodbc.connect(CONEXAO_ODBC)
        cursor = conn.cursor()
        cursor.execute(query, params)

        resultado = True

        # Se a query retornar dados (SELECT ou INSERT/UPDATE com RETURNING)
        if cursor.description:
            colunas = [coluna[0] for coluna in cursor.description]
            if fetch_all:
                linhas = cursor.fetchall()
                resultado = [dict(zip(colunas, linha)) for linha in linhas]
            else:
                linha = cursor.fetchone()
                resultado = dict(zip(colunas, linha)) if linha else None

        # Dá COMMIT SEMPRE (garante que INSERTs com ou sem RETURNING sejam salvos)
        conn.commit()

        cursor.close()
        conn.close()

        return resultado

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro no banco de dados: {str(e)}")

# ROTAS

@app.get("/")
def home():
    return {"status": "API funcionando."}

# region CREATE

# Rota pra create uma tradução (termo pt + termo akwe + categoria)
@app.post("/api/admin/traducao")
def create_traducao(dados: TraducaoCreateSchema):
    conn = None
    try:
        conn = pyodbc.connect(CONEXAO_ODBC)
        cursor = conn.cursor()

        # 1. Busca ou insere o termo em Português
        cursor.execute(
            "SELECT id_termo_pt FROM organograma.termos_portugues WHERE texto_portugues = ?;", 
            (dados.texto_portugues,)
        )
        row_pt = cursor.fetchone()
        
        if row_pt:
            id_termo_pt = row_pt[0]
        else:
            cursor.execute(
                "INSERT INTO organograma.termos_portugues (texto_portugues) VALUES (?) RETURNING id_termo_pt;", 
                (dados.texto_portugues,)
            )
            id_termo_pt = cursor.fetchone()[0]

        # 2. Busca ou insere o termo em Akwẽ
        cursor.execute(
            "SELECT id_termo_akwe FROM organograma.termos_akwe WHERE texto_akwe = ?;", 
            (dados.texto_akwe,)
        )
        row_akwe = cursor.fetchone()

        if row_akwe:
            id_termo_akwe = row_akwe[0]
            if dados.raiz_gramatical:
                cursor.execute(
                    "UPDATE organograma.termos_akwe SET raiz_gramatical = ? WHERE id_termo_akwe = ?;", 
                    (dados.raiz_gramatical, id_termo_akwe)
                )
        else:
            cursor.execute(
                "INSERT INTO organograma.termos_akwe (texto_akwe, raiz_gramatical) VALUES (?, ?) RETURNING id_termo_akwe;", 
                (dados.texto_akwe, dados.raiz_gramatical)
            )
            id_termo_akwe = cursor.fetchone()[0]

        # 3. Insere a Tradução na tabela principal
        sql_traducao = """
            INSERT INTO organograma.termos_traducoes (id_termo_pt, id_termo_akwe, id_categoria, explicacao_contexto)
            VALUES (?, ?, ?, ?)
            RETURNING id_traducao;
        """
        cursor.execute(
            sql_traducao, 
            (id_termo_pt, id_termo_akwe, dados.id_categoria, dados.explicacao_contexto)
        )
        id_traducao = cursor.fetchone()[0]

        # 4. Cria o registro de estatística zerado
        sql_estatistica = """
            INSERT INTO organograma.estatisticas_termos (id_traducao, quantidade_consultas, reproducoes_audio, tempo_retencao_segundos)
            VALUES (?, 0, 0, 0);
        """
        cursor.execute(sql_estatistica, (id_traducao,))

        # Confirma todas as operações na mesma transação
        conn.commit()

        return {
            "status": "success",
            "mensagem": "Tradução cadastrada com sucesso.",
            "id_traducao": id_traducao
        }

    except Exception as e:
        if conn:
            conn.rollback()
        raise HTTPException(status_code=400, detail=f"Erro ao salvar termo: {str(e)}")
    finally:
        if conn:
            conn.close()

# Rota pra create um termo português
@app.post("/api/admin/termospt/create")
def create_termo_pt(texto_portugues: str):
    sql = """
        INSERT INTO organograma.termos_portugues (texto_portugues)
        VALUES (?) 
        RETURNING id_termo_pt;
    """
    resultado = executar_query(sql, (texto_portugues,), fetch_all=False)
    if not resultado:
        return {
            "status": "existente",
            "mensagem": f"O termo português '{texto_portugues}' já existe no banco de dados."
        }

    return {
        "status": "success",
        "mensagem": f"O termo português '{texto_portugues}' foi inserido ID: '{resultado['id_termo_pt']}'."
    }

# Rota pra create um termo akwe
@app.post("/api/admin/termosakwe/create")
def create_termo_akwe(dados: TermoAkweCreateSchema):
    sql = """
        INSERT INTO organograma.termos_akwe (texto_akwe, raiz_gramatical)
        VALUES (?, ?) 
        RETURNING id_termo_akwe;
    """
    resultado = executar_query(sql, (dados.texto_akwe, dados.raiz_gramatical), fetch_all=False)
    if not resultado:
        return {
            "status": "existente",
            "mensagem": f"O termo akwe: '{dados.texto_akwe}' já existe no banco de dados."
        }

    return {
        "status": "success",
        "mensagem": f"O termo akwe '{dados.texto_akwe}' foi inserido ID: '{resultado['id_termo_akwe']}'."
    }

# Rota pra create uma categoria
@app.post("/api/admin/categorias/create")
def create_categoria(nome: str):
    sql = """
        INSERT INTO organograma.categorias (nome)
        VALUES (?)
        ON CONFLICT (nome) DO NOTHING
        RETURNING id_categoria;
    """
    resultado = executar_query(sql, (nome,), fetch_all=False)

    if not resultado:
        return {
            "status": "existente",
            "mensagem": f"A categoria '{nome}' já existe no banco."
        }

    return {
        "status": "sucesso",
        "mensagem": f"Categoria '{nome}' criada!",
        "id_categoria": resultado['id_categoria']
    }

# Rota pra create uma tag
@app.post("/api/admin/tags/create")
def create_tag(nome: str):
    sql = """
        INSERT INTO organograma.tags (nome)
        VALUES (?)
        ON CONFLICT (nome) DO NOTHING
        RETURNING id_tag;
    """
    resultado = executar_query(sql, (nome,), fetch_all=False)

    if not resultado:
        return {
            "status": "existente",
            "mensagem": f"A tag '{nome}' já existe no banco."
        }

    return {
        "status": "success",
        "mensagem": f"Tag '{nome}' criada.",
        "id_tag": resultado['id_tag']
    }

# Rota pra conectar uma tag com uma tradução
@app.post("/api/admin/termotags/create")
def conectar_tag(dados: TermoTagsSchema):
    sql = """
        INSERT INTO organograma.termo_tags (id_traducao, id_tag)
        VALUES (?, ?)
        ON CONFLICT DO NOTHING
        RETURNING id_traducao;
    """

    resultado = executar_query(sql, (dados.id_traducao, dados.id_tag), fetch_all=False)

    return {
        "status": "success",
        "mensagem": f"Tag ID {dados.id_tag} conectada à tradução ID {dados.id_traducao}."
    }

# Rota pra create uma mídia
@app.post("/api/admin/midias/create")
def create_midia(dados: MidiaCreateSchema):
    sql = """
        INSERT INTO organograma.midias (tipo, url_arquivo, id_traducao)
        VALUES (?, ?, ?)
        RETURNING id_midia;
    """

    resultado = executar_query(sql, (dados.tipo, dados.url_arquivo, dados.id_traducao), fetch_all=False)

    return {
        "status": "success",
        "mensagem": "Mídia cadastrada com sucesso.",
        "id_midia": resultado['id_midia'] if resultado else None
    }

# Rota pra criar uma estatística
@app.post("/api/admin/estatisticas/create")
def create_estatistica(id_traducao: int):
    try:
        sql = """
            INSERT INTO organograma.estatisticas_termos (id_traducao)
            VALUES (?)
            RETURNING id_estatistica;
        """
        resultado = executar_query(sql, (id_traducao,), fetch_all=False)
        return {
            "status": "success",
            "mensagem": f"Estatística criada para a tradução ID {id_traducao}.",
            "id_estatistica": resultado['id_estatistica'] if resultado else None
        }

    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail=f"Não foi possível criar a estatística. (Erro: {str(e)})"
        )

# endregion

# region READ

# Buscar um termo
@app.get("/api/search")
def buscar_termo(q: Optional[str] = Query(None)):
    if not q:
        return {"resultados": []}

    termo_busca = f"%{q.lower().strip()}%"
    
    sql = """
        SELECT 
            t.id_traducao,
            tp.texto_portugues,
            ta.texto_akwe,
            ta.raiz_gramatical,
            c.nome AS categoria,
            t.explicacao_contexto
        FROM organograma.termos_traducoes t
        INNER JOIN organograma.termos_portugues tp ON t.id_termo_pt = tp.id_termo_pt
        INNER JOIN organograma.termos_akwe ta ON t.id_termo_akwe = ta.id_termo_akwe
        INNER JOIN organograma.categorias c ON t.id_categoria = c.id_categoria
        WHERE LOWER(tp.texto_portugues) LIKE ? 
           OR LOWER(ta.texto_akwe) LIKE ? 
           OR LOWER(ta.raiz_gramatical) LIKE ?;
    """
    
    resultados = executar_query(sql, (termo_busca, termo_busca, termo_busca))
    return {"busca": q, "total": len(resultados), "dados": resultados}

# Exibir estatísticas em resumo pro painel
@app.get("/api/admin/estatisticas/overview")
def overview_estatisticas():
    sql = """
        SELECT 
            COUNT(DISTINCT t.id_traducao) AS total_traducoes,
            COALESCE(SUM(e.quantidade_consultas), 0) AS total_consultas,
            COALESCE(SUM(e.reproducoes_audio), 0) AS total_audios_ouvidos,
            ROUND(AVG(e.nivel_clareza), 2) AS media_nivel_clareza
        FROM organograma.termos_traducoes t
        LEFT JOIN organograma.estatisticas_termos e ON t.id_traducao = e.id_traducao;
    """
    stats = executar_query(sql, fetch_all=False)
    return {"estatisticas": stats}

# Exibir todas estatísticas
@app.get("/api/admin/estatisticas/read")
def read_estatisticas():
    sql = """
        SELECT * FROM organograma.estatisticas_termos;
    """

    resultado = executar_query(sql, fetch_all=True)

    return {"estatisticas": resultado}

# Listar todas as traduções formatados para a tabela do Admin
@app.get("/api/admin/traducoes/read")
def listar_traducoes_admin():
    sql = """
        SELECT 
            t.id_traducao,
            tp.texto_portugues,
            ta.texto_akwe,
            ta.raiz_gramatical,
            c.nome AS categoria,
            t.explicacao_contexto,
            STRING_AGG(DISTINCT tg.nome, ', ') AS tags,
            STRING_AGG(DISTINCT m.url_arquivo, ', ') AS midias
        FROM organograma.termos_traducoes t
        INNER JOIN organograma.termos_portugues tp ON t.id_termo_pt = tp.id_termo_pt
        INNER JOIN organograma.termos_akwe ta ON t.id_termo_akwe = ta.id_termo_akwe
        INNER JOIN organograma.categorias c ON t.id_categoria = c.id_categoria
        LEFT JOIN organograma.termo_tags tt ON t.id_traducao = tt.id_traducao
        LEFT JOIN organograma.tags tg ON tt.id_tag = tg.id_tag
        LEFT JOIN organograma.midias m ON t.id_traducao = m.id_traducao
        GROUP BY t.id_traducao, tp.texto_portugues, ta.texto_akwe, ta.raiz_gramatical, c.nome, t.explicacao_contexto
        ORDER BY t.id_traducao DESC;
    """
    return {"termos": executar_query(sql)}

@app.get("/api/traducoes/read")
def read_traducoes():
    sql = """
        SELECT * FROM organograma.termos_traducoes;
    """

    resultado = executar_query(sql, fetch_all=True)
    
    return {
        "termos_traducoes": resultado
    }

# Listar todas as categorias
@app.get("/api/categorias/read")
def read_categorias():
    sql = """
        SELECT * FROM organograma.categorias;
    """

    resultado = executar_query(sql, fetch_all=True)

    return {"categorias": resultado}

# Listar todas as mídias
@app.get("/api/midias/read")
def read_midias():
    sql = """
        SELECT * FROM organograma.midias;
    """

    resultado = executar_query(sql, fetch_all=True)

    return {
        "midias": resultado
    }

# Listar todas as tags
@app.get("/api/tags/read")
def read_tags():
    sql = """
        SELECT * FROM organograma.tags;
    """

    resultado = executar_query(sql, fetch_all=True)

    return {
        "tags": resultado
    }

# Listar todas conexões termo_tags
@app.get("/api/termotags/read")
def read_termotags():
    sql = """
        SELECT * FROM organograma.termo_tags;
    """

    resultado = executar_query(sql, fetch_all=True)

    return {
        "termo_tags": resultado
    }

# Listar todos os termos akwe
@app.get("/api/termosakwe/read")
def read_termos_akwe():
    sql = """
        SELECT * FROM organograma.termos_akwe;
    """

    resultado = executar_query(sql, fetch_all=True)

    return {
        "termos_akwe": resultado
    }

# Listar todos os termos pt
@app.get("/api/termospt/read")
def read_termos_pt():
    sql = """
        SELECT * FROM organograma.termos_portugues;
    """

    resultado = executar_query(sql, fetch_all=True)

    return {
        "termos_portugues": resultado
    }

# endregion

# region UPDATE

# Incrementa consultas do termo
@app.patch("/api/traducao/{id_traducao}/consultar")
def registrar_consulta(id_traducao: int):
    sql = """
        UPDATE organograma.estatisticas_termos 
        SET quantidade_consultas = quantidade_consultas + 1 
        WHERE id_traducao = ?
        RETURNING id_estatistica;
    """
    resultado = executar_query(sql, (id_traducao,), fetch_all=False)
    if not resultado:
        raise HTTPException(status_code=404, detail=f"Tradução ID {id_traducao} não encontrada para estatística.")
    return {"status": "Consulta registrada."}

# Rota de atualização para a tabela principal de traduções
@app.put("/api/admin/traducoes/update")
def update_traducao(dados: TraducaoUpdateSchema):
    try:
        sql = """
            UPDATE organograma.termos_traducoes
            SET id_categoria = ?,
                explicacao_contexto = ?
            WHERE id_traducao = ?
            RETURNING id_traducao;
        """
        resultado = executar_query(sql, (dados.id_categoria, dados.explicacao_contexto, dados.id_traducao), fetch_all=False)
        
        if not resultado:
            raise HTTPException(status_code=404, detail=f"Tradução ID {dados.id_traducao} não encontrada.")

        return {
            "status": "success",
            "mensagem": "Tradução atualizada com sucesso."
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail=f"Não foi possível atualizar a tradução. (Erro: {str(e)})"
        )

# Atualiza o nome de uma categoria
@app.put("/api/admin/categorias/update")
def update_categoria(dados: CategoriaUpdateSchema):
    try:
        sql = """
            UPDATE organograma.categorias
            SET nome = ?
            WHERE id_categoria = ?
            RETURNING id_categoria;
        """

        resultado = executar_query(sql, (dados.nome, dados.id_categoria), fetch_all=False)

        if not resultado:
            raise HTTPException(status_code=404, detail=f"Categoria ID {dados.id_categoria} não encontrada.")

        return {
            "status": "success",
            "mensagem": "Categoria atualizada."
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail=f"Não foi possível atualizar a categoria. (Erro: {str(e)})"
        )

# Atualiza os dados de uma estatística
@app.put("/api/admin/estatisticas/update")
def update_estatisticas(dados: EstatisticasUpdateSchema):
    try:
        sql = """
            UPDATE organograma.estatisticas_termos
            SET id_traducao = ?,
                quantidade_consultas = ?,
                reproducoes_audio = ?,
                nivel_clareza = ?,
                tempo_retencao_segundos = ?
            WHERE id_estatistica = ?
            RETURNING id_estatistica;
        """

        resultado = executar_query(sql, (dados.id_traducao, dados.quantidade_consultas, dados.reproducoes_audio, dados.nivel_clareza, dados.tempo_retencao_segundos, dados.id_estatistica), fetch_all=False)

        if not resultado:
            raise HTTPException(status_code=404, detail=f"Estatística ID {dados.id_estatistica} não encontrada.")

        return {
            "status": "success",
            "mensagem": "Estatística atualizada."
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail= f"Não foi possível atualizar a estatística. (Erro: {str(e)})"
        )

# Atualiza uma mídia
@app.put("/api/admin/midias/update")
def update_midia(dados: MidiaUpdateSchema):
    try:
        sql = """
            UPDATE organograma.midias
            SET tipo = ?,
                url_arquivo = ?,
                id_traducao = ?
            WHERE id_midia = ?
            RETURNING id_midia;
        """

        resultado = executar_query(sql, (dados.tipo, dados.url_arquivo, dados.id_traducao, dados.id_midia), fetch_all=False)

        if not resultado:
            raise HTTPException(status_code=404, detail=f"Mídia ID {dados.id_midia} não encontrada.")

        return {
            "status": "success",
            "mensagem": "Mídia atualizada com sucesso."
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
                status_code=400,
                detail= f"Não foi possível atualizar a mídia. (Erro: {str(e)})"
            )

# Atualiza uma tag
@app.put("/api/admin/tags/update")
def update_tag(dados: TagUpdateSchema):
    try:
        sql = """
            UPDATE organograma.tags
            SET nome = ?
            WHERE id_tag = ?
            RETURNING id_tag;
        """

        resultado = executar_query(sql, (dados.nome, dados.id_tag), fetch_all=False)

        if not resultado:
            raise HTTPException(status_code=404, detail=f"Tag ID {dados.id_tag} não encontrada.")

        return {
            "status": "success",
            "mensagem": "Tag atualizada com sucesso."
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
                status_code=400,
                detail= f"Não foi possível atualizar a tag. (Erro: {str(e)})"
            )

# Atualiza um termo akwe
@app.put("/api/admin/termosakwe/update")
def update_termo_akwe(dados: TermoAkweUpdateSchema):
    try:
        if dados.raiz_gramatical:
            sql = """
                UPDATE organograma.termos_akwe
                SET texto_akwe = ?,
                    raiz_gramatical = ?
                WHERE id_termo_akwe = ?
                RETURNING id_termo_akwe;
            """
            resultado = executar_query(sql, (dados.texto_akwe, dados.raiz_gramatical, dados.id_termo_akwe), fetch_all=False)

        else:
            sql = """
                UPDATE organograma.termos_akwe
                SET texto_akwe = ?
                WHERE id_termo_akwe = ?
                RETURNING id_termo_akwe;
            """
            resultado = executar_query(sql, (dados.texto_akwe, dados.id_termo_akwe), fetch_all=False)

        if not resultado:
            raise HTTPException(status_code=404, detail=f"Termo Akwẽ ID {dados.id_termo_akwe} não encontrado.")

        return {
            "status": "success",
            "mensagem": "Termo akwe atualizado."
        }
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail= f"Não foi possível atualizar o termo akwe. (Erro: {str(e)})"
        )

# Atualiza um termo português
@app.put("/api/admin/termospt/update")
def update_termo_pt(dados: TermoPtUpdateSchema):
    try:
        sql = """
            UPDATE organograma.termos_portugues
            SET texto_portugues = ?
            WHERE id_termo_pt = ?
            RETURNING id_termo_pt;
        """

        resultado = executar_query(sql, (dados.texto_portugues, dados.id_termo_pt), fetch_all=False)

        if not resultado:
            raise HTTPException(status_code=404, detail=f"Termo PT ID {dados.id_termo_pt} não encontrado.")

        return {
            "status": "success",
            "mensagem": "Termo português atualizada com sucesso."
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
                status_code=400,
                detail= f"Não foi possível atualizar o termo português. (Erro: {str(e)})"
            )

# endregion

# region DELETE

# Rota pra deletar uma tradução
@app.delete("/api/admin/traducao/delete")
def delete_traducao(id_traducao: int):
    try:
        # 1. Remove estatística associada primeiro (por causa da FK)
        executar_query("DELETE FROM organograma.estatisticas_termos WHERE id_traducao = ?;", (id_traducao,))
        
        # 2. Remove tags associadas
        executar_query("DELETE FROM organograma.termo_tags WHERE id_traducao = ?;", (id_traducao,))
        
        # 3. Remove mídias associadas
        executar_query("DELETE FROM organograma.midias WHERE id_traducao = ?;", (id_traducao,))

        # 4. Remove a tradução principal
        resultado = executar_query("DELETE FROM organograma.termos_traducoes WHERE id_traducao = ? RETURNING id_traducao;", (id_traducao,), fetch_all=False)
        
        if not resultado:
            raise HTTPException(status_code=404, detail=f"Tradução ID {id_traducao} não encontrada.")

        return {"status": "Sucesso", "mensagem": f"Tradução #{id_traducao} removida com sucesso!"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail="Não foi possível deletar a tradução."
        )

# Rota pra deletar um termo português
@app.delete("/api/admin/termopt/delete")
def delete_termo_pt(id_termo_pt: int):
    try:
        sql = """
            DELETE FROM organograma.termos_portugues
            WHERE id_termo_pt = ?
            RETURNING id_termo_pt;
        """
        resultado = executar_query(sql, (id_termo_pt,), fetch_all=False)

        if not resultado:
            raise HTTPException(status_code=404, detail=f"Termo PT ID {id_termo_pt} não encontrado.")

        return {
            "status": "success",
            "mensagem": f"Termo ID {id_termo_pt} deletado."
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail="Não foi possível deletar: o termo está sendo utiliziado em uma ou mais traduções."
        )

# Rota pra deletar um termo akwe
@app.delete("/api/admin/termoakwe/delete")
def delete_termo_akwe(id_termo_akwe: int):
    try:
        sql = """
            DELETE FROM organograma.termos_akwe
            WHERE id_termo_akwe = ?
            RETURNING id_termo_akwe;
        """
        resultado = executar_query(sql, (id_termo_akwe,), fetch_all=False)
        
        if not resultado:
            raise HTTPException(status_code=404, detail=f"Termo Akwẽ ID {id_termo_akwe} não encontrado.")

        return {
            "status": "success",
            "mensagem": f"Termo Akwẽ ID {id_termo_akwe} deletado."
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail="Não foi possível deletar: o termo está sendo utilziado em uma ou mais traduções."
        )

# Rota pra deletar uma categoria
@app.delete("/api/admin/categorias/delete")
def delete_categoria(id_categoria: int):
    try:
        sql = """
            DELETE FROM organograma.categorias WHERE id_categoria = ? RETURNING id_categoria;
        """

        resultado = executar_query(sql, (id_categoria,), fetch_all=False)

        if not resultado:
            raise HTTPException(status_code=404, detail=f"Categoria ID {id_categoria} não encontrada.")

        return {
            "status": "success",
            "mensagem": f"Categoria ID {id_categoria} deletada."
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail=f"Não foi possível deletar a categoria ID {id_categoria}: ela possui traduções vinculadas. (Erro: {str(e)})"
        )

# Rota pra deletar uma mídia
@app.delete("/api/admin/midias/delete")
def delete_midia(id_midia: int):
    try:
        sql = """
            DELETE FROM organograma.midias WHERE id_midia = ? RETURNING id_midia;
        """

        resultado = executar_query(sql, (id_midia,), fetch_all=False)

        if not resultado:
            raise HTTPException(status_code=404, detail=f"Mídia ID {id_midia} não encontrada.")

        return {
            "status": "success",
            "mensagem": f"Mídia ID {id_midia} deletada."
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail="Não foi possível deletar a midia."
        )

# Rota pra desconectar uma tag de uma tradução
@app.delete("/api/admin/termotags/delete")
def desconectar_tag(dados: TermoTagsSchema):
    try:
        sql = """
            DELETE FROM organograma.termo_tags
            WHERE id_traducao = ? AND id_tag = ?
            RETURNING id_traducao;
        """

        resultado = executar_query(sql, (dados.id_traducao, dados.id_tag), fetch_all=False)

        if not resultado:
            raise HTTPException(status_code=404, detail="Conexão de tag e tradução não encontrada.")

        return {
            "status": "success",
            "mensagem": f"Tag ID {dados.id_tag} desconectada da tradução ID {dados.id_traducao}."
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail="Não foi possível deletar a conexão de tag com tradução."
        )

# Rota pra deletar estatística
@app.delete("/api/admin/estatisticas/delete")
def delete_estatistica(id_estatistica: int):
    try:
        sql = """
            DELETE FROM organograma.estatisticas_termos
            WHERE id_estatistica = ?
            RETURNING id_estatistica;
        """

        resultado = executar_query(sql, (id_estatistica,), fetch_all=False)

        if not resultado:
            raise HTTPException(status_code=404, detail=f"Estatística ID {id_estatistica} não encontrada.")

        return {
            "status": "success",
            "mensagem": "Estatística deletada."
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail=f"Não foi possível deletar a estatística. (Erro: {str(e)})"
        )

# Deletar tag
@app.delete("/api/admin/tags/delete")
def delete_tag(id_tag: int):
    try:
        sql = """
            DELETE FROM organograma.tags WHERE id_tag = ? RETURNING id_tag;
        """

        resultado = executar_query(sql, (id_tag,), fetch_all=False)

        if not resultado:
            raise HTTPException(status_code=404, detail=f"Tag ID {id_tag} não encontrada.")

        return {
            "status": "success",
            "mensagem": f"Tag ID {id_tag} deletada."
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail=f"Não foi possível deletar: a tag está sendo utilziado em uma ou mais relação de tradução com tag. (Erro: {str(e)})"
        )

# endregion