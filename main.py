import os
from dotenv import load_dotenv
import pyodbc
from fastapi import FastAPI, Query, HTTPException
from typing import Optional
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware

# Carrega as variáveis do arquivo .env
load_dotenv()
DATABASE_LOGIN = os.getenv("DATABASE_LOGIN")
DATABASE_PASSWORD = os.getenv("DATABASE_PASSWORD")

# Instância principal da aplicação FastAPI
app = FastAPI(
    title="API - Dicionário Akwẽ",
    description="Backend RESTful para gerenciamento de dados do dicionário"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

CONEXAO_ODBC = (
    f"DRIVER={{PostgreSQL Unicode}};"
    f"SERVER=localhost;"
    f"PORT=5432;"
    f"DATABASE=db_akwe;"
    f"UID={DATABASE_LOGIN};"
    f"PWD={DATABASE_PASSWORD};"
)

# region SCHEMAS PYDANTIC

class TraducaoCreateSchema(BaseModel):
    texto_portugues: str
    texto_akwe: str
    raiz_gramatical: Optional[str] = None
    id_categoria: int
    explicacao_contexto: Optional[str] = None

class TraducaoUpdateSchema(BaseModel):
    id_categoria: int
    explicacao_contexto: Optional[str] = None

class TermoPtSchema(BaseModel):
    texto_portugues: str

class TermoAkweSchema(BaseModel):
    texto_akwe: str
    raiz_gramatical: Optional[str] = None

class CategoriaSchema(BaseModel):
    nome: str

class TagSchema(BaseModel):
    nome: str

class TermoTagsSchema(BaseModel):
    id_traducao: int
    id_tag: int

class MidiaCreateSchema(BaseModel):
    tipo: str
    url_arquivo: str
    id_traducao: int

class MidiaUpdateSchema(BaseModel):
    tipo: str
    url_arquivo: str
    id_traducao: int

class EstatisticaCreateSchema(BaseModel):
    id_traducao: int

class EstatisticaUpdateSchema(BaseModel):
    id_traducao: int
    quantidade_consultas: int
    reproducoes_audio: int
    nivel_clareza: int
    tempo_retencao_segundos: int

# endregion

# region FUNÇÕES UTILITÁRIAS 

def executar_query(query: str, params: tuple = (), fetch_all: bool = True):
    """Abre conexão ODBC, executa a SQL com suporte a RETURNING e encerra o cursor."""
    try:
        conn = pyodbc.connect(CONEXAO_ODBC)
        cursor = conn.cursor()
        cursor.execute(query, params)

        resultado = True

        if cursor.description:
            colunas = [coluna[0] for coluna in cursor.description]
            if fetch_all:
                linhas = cursor.fetchall()
                resultado = [dict(zip(colunas, linha)) for linha in linhas]
            else:
                linha = cursor.fetchone()
                resultado = dict(zip(colunas, linha)) if linha else None

        conn.commit()
        cursor.close()
        conn.close()

        return resultado

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro no banco de dados: {str(e)}")

# endregion

@app.get("/")
def home():
    return {"status": "API funcionando."}

# region ROTAS DE CRIAÇÃO (POST) 

@app.post("/api/admin/traducoes", status_code=201)
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

        # 3. Insere a Tradução principal
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

        # 4. Inicializa o registro de estatística
        sql_estatistica = """
            INSERT INTO organograma.estatisticas_termos (id_traducao, quantidade_consultas, reproducoes_audio, tempo_retencao_segundos)
            VALUES (?, 0, 0, 0);
        """
        cursor.execute(sql_estatistica, (id_traducao,))

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

@app.post("/api/admin/termos-portugues", status_code=201)
def create_termo_pt(dados: TermoPtSchema):
    sql = """
        INSERT INTO organograma.termos_portugues (texto_portugues)
        VALUES (?) 
        RETURNING id_termo_pt;
    """
    resultado = executar_query(sql, (dados.texto_portugues,), fetch_all=False)
    if not resultado:
        return {
            "status": "existente",
            "mensagem": f"O termo português '{dados.texto_portugues}' já existe no banco de dados."
        }

    return {
        "status": "success",
        "mensagem": f"O termo português '{dados.texto_portugues}' foi inserido com sucesso.",
        "id_termo_pt": resultado['id_termo_pt']
    }

@app.post("/api/admin/termos-akwe", status_code=201)
def create_termo_akwe(dados: TermoAkweSchema):
    sql = """
        INSERT INTO organograma.termos_akwe (texto_akwe, raiz_gramatical)
        VALUES (?, ?) 
        RETURNING id_termo_akwe;
    """
    resultado = executar_query(sql, (dados.texto_akwe, dados.raiz_gramatical), fetch_all=False)
    if not resultado:
        return {
            "status": "existente",
            "mensagem": f"O termo Akwẽ '{dados.texto_akwe}' já existe no banco de dados."
        }

    return {
        "status": "success",
        "mensagem": f"O termo Akwẽ '{dados.texto_akwe}' foi inserido com sucesso.",
        "id_termo_akwe": resultado['id_termo_akwe']
    }

@app.post("/api/admin/categorias", status_code=201)
def create_categoria(dados: CategoriaSchema):
    sql = """
        INSERT INTO organograma.categorias (nome)
        VALUES (?)
        ON CONFLICT (nome) DO NOTHING
        RETURNING id_categoria;
    """
    resultado = executar_query(sql, (dados.nome,), fetch_all=False)

    if not resultado:
        return {
            "status": "existente",
            "mensagem": f"A categoria '{dados.nome}' já existe no banco."
        }

    return {
        "status": "success",
        "mensagem": f"Categoria '{dados.nome}' criada com sucesso.",
        "id_categoria": resultado['id_categoria']
    }

@app.post("/api/admin/tags", status_code=201)
def create_tag(dados: TagSchema):
    sql = """
        INSERT INTO organograma.tags (nome)
        VALUES (?)
        ON CONFLICT (nome) DO NOTHING
        RETURNING id_tag;
    """
    resultado = executar_query(sql, (dados.nome,), fetch_all=False)

    if not resultado:
        return {
            "status": "existente",
            "mensagem": f"A tag '{dados.nome}' já existe no banco."
        }

    return {
        "status": "success",
        "mensagem": f"Tag '{dados.nome}' criada com sucesso.",
        "id_tag": resultado['id_tag']
    }

@app.post("/api/admin/termo-tags", status_code=201)
def conectar_tag(dados: TermoTagsSchema):
    sql = """
        INSERT INTO organograma.termo_tags (id_traducao, id_tag)
        VALUES (?, ?)
        ON CONFLICT DO NOTHING
        RETURNING id_traducao;
    """
    executar_query(sql, (dados.id_traducao, dados.id_tag), fetch_all=False)

    return {
        "status": "success",
        "mensagem": f"Tag ID {dados.id_tag} conectada à tradução ID {dados.id_traducao}."
    }

@app.post("/api/admin/midias", status_code=201)
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

@app.post("/api/admin/estatisticas", status_code=201)
def create_estatistica(dados: EstatisticaCreateSchema):
    try:
        sql = """
            INSERT INTO organograma.estatisticas_termos (id_traducao)
            VALUES (?)
            RETURNING id_estatistica;
        """
        resultado = executar_query(sql, (dados.id_traducao,), fetch_all=False)
        return {
            "status": "success",
            "mensagem": f"Estatística criada para a tradução ID {dados.id_traducao}.",
            "id_estatistica": resultado['id_estatistica'] if resultado else None
        }

    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail=f"Não foi possível criar a estatística: {str(e)}"
        )

# endregion

# region ROTAS DE LEITURA (GET)

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

@app.get("/api/admin/estatisticas")
def read_estatisticas():
    sql = "SELECT * FROM organograma.estatisticas_termos;"
    return {"estatisticas": executar_query(sql, fetch_all=True)}

@app.get("/api/admin/traducoes")
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

@app.get("/api/traducoes")
def read_traducoes():
    sql = "SELECT * FROM organograma.termos_traducoes;"
    return {"termos_traducoes": executar_query(sql, fetch_all=True)}

@app.get("/api/categorias")
def read_categorias():
    sql = "SELECT * FROM organograma.categorias;"
    return {"categorias": executar_query(sql, fetch_all=True)}

@app.get("/api/midias")
def read_midias():
    sql = "SELECT * FROM organograma.midias;"
    return {"midias": executar_query(sql, fetch_all=True)}

@app.get("/api/tags")
def read_tags():
    sql = "SELECT * FROM organograma.tags;"
    return {"tags": executar_query(sql, fetch_all=True)}

@app.get("/api/termo-tags")
def read_termotags():
    sql = "SELECT * FROM organograma.termo_tags;"
    return {"termo_tags": executar_query(sql, fetch_all=True)}

@app.get("/api/termos-akwe")
def read_termos_akwe():
    sql = "SELECT * FROM organograma.termos_akwe;"
    return {"termos_akwe": executar_query(sql, fetch_all=True)}

@app.get("/api/termos-portugues")
def read_termos_pt():
    sql = "SELECT * FROM organograma.termos_portugues;"
    return {"termos_portugues": executar_query(sql, fetch_all=True)}

# endregion

# region ROTAS DE ATUALIZAÇÃO (PUT / PATCH)

@app.patch("/api/traducoes/{id_traducao}/consultar")
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
    return {"status": "success", "mensagem": "Consulta registrada com sucesso."}

@app.put("/api/admin/traducoes/{id_traducao}")
def update_traducao(id_traducao: int, dados: TraducaoUpdateSchema):
    try:
        sql = """
            UPDATE organograma.termos_traducoes
            SET id_categoria = ?,
                explicacao_contexto = ?
            WHERE id_traducao = ?
            RETURNING id_traducao;
        """
        resultado = executar_query(sql, (dados.id_categoria, dados.explicacao_contexto, id_traducao), fetch_all=False)
        
        if not resultado:
            raise HTTPException(status_code=404, detail=f"Tradução ID {id_traducao} não encontrada.")

        return {"status": "success", "mensagem": "Tradução atualizada com sucesso."}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Não foi possível atualizar a tradução: {str(e)}")

@app.put("/api/admin/categorias/{id_categoria}")
def update_categoria(id_categoria: int, dados: CategoriaSchema):
    try:
        sql = """
            UPDATE organograma.categorias
            SET nome = ?
            WHERE id_categoria = ?
            RETURNING id_categoria;
        """
        resultado = executar_query(sql, (dados.nome, id_categoria), fetch_all=False)

        if not resultado:
            raise HTTPException(status_code=404, detail=f"Categoria ID {id_categoria} não encontrada.")

        return {"status": "success", "mensagem": "Categoria atualizada com sucesso."}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Não foi possível atualizar a categoria: {str(e)}")

@app.put("/api/admin/estatisticas/{id_estatistica}")
def update_estatisticas(id_estatistica: int, dados: EstatisticaUpdateSchema):
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
        resultado = executar_query(sql, (dados.id_traducao, dados.quantidade_consultas, dados.reproducoes_audio, dados.nivel_clareza, dados.tempo_retencao_segundos, id_estatistica), fetch_all=False)

        if not resultado:
            raise HTTPException(status_code=404, detail=f"Estatística ID {id_estatistica} não encontrada.")

        return {"status": "success", "mensagem": "Estatística atualizada com sucesso."}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Não foi possível atualizar a estatística: {str(e)}")

@app.put("/api/admin/midias/{id_midia}")
def update_midia(id_midia: int, dados: MidiaUpdateSchema):
    try:
        sql = """
            UPDATE organograma.midias
            SET tipo = ?,
                url_arquivo = ?,
                id_traducao = ?
            WHERE id_midia = ?
            RETURNING id_midia;
        """
        resultado = executar_query(sql, (dados.tipo, dados.url_arquivo, dados.id_traducao, id_midia), fetch_all=False)

        if not resultado:
            raise HTTPException(status_code=404, detail=f"Mídia ID {id_midia} não encontrada.")

        return {"status": "success", "mensagem": "Mídia atualizada com sucesso."}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Não foi possível atualizar a mídia: {str(e)}")

@app.put("/api/admin/tags/{id_tag}")
def update_tag(id_tag: int, dados: TagSchema):
    try:
        sql = """
            UPDATE organograma.tags
            SET nome = ?
            WHERE id_tag = ?
            RETURNING id_tag;
        """
        resultado = executar_query(sql, (dados.nome, id_tag), fetch_all=False)

        if not resultado:
            raise HTTPException(status_code=404, detail=f"Tag ID {id_tag} não encontrada.")

        return {"status": "success", "mensagem": "Tag atualizada com sucesso."}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Não foi possível atualizar a tag: {str(e)}")

@app.put("/api/admin/termos-akwe/{id_termo_akwe}")
def update_termo_akwe(id_termo_akwe: int, dados: TermoAkweSchema):
    try:
        if dados.raiz_gramatical:
            sql = """
                UPDATE organograma.termos_akwe
                SET texto_akwe = ?,
                    raiz_gramatical = ?
                WHERE id_termo_akwe = ?
                RETURNING id_termo_akwe;
            """
            resultado = executar_query(sql, (dados.texto_akwe, dados.raiz_gramatical, id_termo_akwe), fetch_all=False)
        else:
            sql = """
                UPDATE organograma.termos_akwe
                SET texto_akwe = ?
                WHERE id_termo_akwe = ?
                RETURNING id_termo_akwe;
            """
            resultado = executar_query(sql, (dados.texto_akwe, id_termo_akwe), fetch_all=False)

        if not resultado:
            raise HTTPException(status_code=404, detail=f"Termo Akwẽ ID {id_termo_akwe} não encontrado.")

        return {"status": "success", "mensagem": "Termo Akwẽ atualizado com sucesso."}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Não foi possível atualizar o termo Akwẽ: {str(e)}")

@app.put("/api/admin/termos-portugues/{id_termo_pt}")
def update_termo_pt(id_termo_pt: int, dados: TermoPtSchema):
    try:
        sql = """
            UPDATE organograma.termos_portugues
            SET texto_portugues = ?
            WHERE id_termo_pt = ?
            RETURNING id_termo_pt;
        """
        resultado = executar_query(sql, (dados.texto_portugues, id_termo_pt), fetch_all=False)

        if not resultado:
            raise HTTPException(status_code=404, detail=f"Termo PT ID {id_termo_pt} não encontrado.")

        return {"status": "success", "mensagem": "Termo português atualizado com sucesso."}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Não foi possível atualizar o termo português: {str(e)}")

# endregion

# region ROTAS DE DELEÇÃO (DELETE)

@app.delete("/api/admin/traducoes/{id_traducao}")
def delete_traducao(id_traducao: int):
    try:
        executar_query("DELETE FROM organograma.estatisticas_termos WHERE id_traducao = ?;", (id_traducao,))
        executar_query("DELETE FROM organograma.termo_tags WHERE id_traducao = ?;", (id_traducao,))
        executar_query("DELETE FROM organograma.midias WHERE id_traducao = ?;", (id_traducao,))

        resultado = executar_query("DELETE FROM organograma.termos_traducoes WHERE id_traducao = ? RETURNING id_traducao;", (id_traducao,), fetch_all=False)
        
        if not resultado:
            raise HTTPException(status_code=404, detail=f"Tradução ID {id_traducao} não encontrada.")

        return {"status": "success", "mensagem": f"Tradução #{id_traducao} removida com sucesso."}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail="Não foi possível deletar a tradução.")

@app.delete("/api/admin/termos-portugues/{id_termo_pt}")
def delete_termo_pt(id_termo_pt: int):
    try:
        sql = "DELETE FROM organograma.termos_portugues WHERE id_termo_pt = ? RETURNING id_termo_pt;"
        resultado = executar_query(sql, (id_termo_pt,), fetch_all=False)

        if not resultado:
            raise HTTPException(status_code=404, detail=f"Termo PT ID {id_termo_pt} não encontrado.")

        return {"status": "success", "mensagem": f"Termo ID {id_termo_pt} deletado com sucesso."}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail="Não foi possível deletar: o termo está sendo utilizado em uma ou mais traduções.")

@app.delete("/api/admin/termos-akwe/{id_termo_akwe}")
def delete_termo_akwe(id_termo_akwe: int):
    try:
        sql = "DELETE FROM organograma.termos_akwe WHERE id_termo_akwe = ? RETURNING id_termo_akwe;"
        resultado = executar_query(sql, (id_termo_akwe,), fetch_all=False)
        
        if not resultado:
            raise HTTPException(status_code=404, detail=f"Termo Akwẽ ID {id_termo_akwe} não encontrado.")

        return {"status": "success", "mensagem": f"Termo Akwẽ ID {id_termo_akwe} deletado com sucesso."}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail="Não foi possível deletar: o termo está sendo utilizado em uma ou mais traduções.")

@app.delete("/api/admin/categorias/{id_categoria}")
def delete_categoria(id_categoria: int):
    try:
        sql = "DELETE FROM organograma.categorias WHERE id_categoria = ? RETURNING id_categoria;"
        resultado = executar_query(sql, (id_categoria,), fetch_all=False)

        if not resultado:
            raise HTTPException(status_code=404, detail=f"Categoria ID {id_categoria} não encontrada.")

        return {"status": "success", "mensagem": f"Categoria ID {id_categoria} deletada com sucesso."}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Não foi possível deletar a categoria ID {id_categoria}: ela possui traduções vinculadas.")

@app.delete("/api/admin/midias/{id_midia}")
def delete_midia(id_midia: int):
    try:
        sql = "DELETE FROM organograma.midias WHERE id_midia = ? RETURNING id_midia;"
        resultado = executar_query(sql, (id_midia,), fetch_all=False)

        if not resultado:
            raise HTTPException(status_code=404, detail=f"Mídia ID {id_midia} não encontrada.")

        return {"status": "success", "mensagem": f"Mídia ID {id_midia} deletada com sucesso."}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail="Não foi possível deletar a mídia.")

@app.delete("/api/admin/termo-tags/{id_traducao}/{id_tag}")
def desconectar_tag(id_traducao: int, id_tag: int):
    try:
        sql = "DELETE FROM organograma.termo_tags WHERE id_traducao = ? AND id_tag = ? RETURNING id_traducao;"
        resultado = executar_query(sql, (id_traducao, id_tag), fetch_all=False)

        if not resultado:
            raise HTTPException(status_code=404, detail="Conexão de tag e tradução não encontrada.")

        return {"status": "success", "mensagem": f"Tag ID {id_tag} desconectada da tradução ID {id_traducao}."}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail="Não foi possível deletar a conexão de tag com tradução.")

@app.delete("/api/admin/estatisticas/{id_estatistica}")
def delete_estatistica(id_estatistica: int):
    try:
        sql = "DELETE FROM organograma.estatisticas_termos WHERE id_estatistica = ? RETURNING id_estatistica;"
        resultado = executar_query(sql, (id_estatistica,), fetch_all=False)

        if not resultado:
            raise HTTPException(status_code=404, detail=f"Estatística ID {id_estatistica} não encontrada.")

        return {"status": "success", "mensagem": "Estatística deletada com sucesso."}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Não foi possível deletar a estatística: {str(e)}")

@app.delete("/api/admin/tags/{id_tag}")
def delete_tag(id_tag: int):
    try:
        sql = "DELETE FROM organograma.tags WHERE id_tag = ? RETURNING id_tag;"
        resultado = executar_query(sql, (id_tag,), fetch_all=False)

        if not resultado:
            raise HTTPException(status_code=404, detail=f"Tag ID {id_tag} não encontrada.")

        return {"status": "success", "mensagem": f"Tag ID {id_tag} deletada com sucesso."}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail="Não foi possível deletar: a tag está sendo utilizada em uma ou mais traduções.")

#endregion