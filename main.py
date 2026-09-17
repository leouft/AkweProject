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


class NovoTermoSchema(BaseModel):
        texto_portugues: str
        texto_akwe: str
        raiz_gramatical: Optional[str] = None
        id_categoria: int
        explicacao_contexto: Optional[str] = None

class NovaCategoriaSchema(BaseModel):
    nome: str

class NovaTagSchema(BaseModel):
    nome: str

class NovaTermoTagsSchema(BaseModel):
    id_traducao: int
    id_tag: int

class NovaMidiaSchema(BaseModel):
    tipo: str
    url_arquivo: str
    id_traducao: int

# ROTAS

def executar_query(query: str, params: tuple = (), fetch_all: bool = True):
    """Abre conexão ODBC, executa a SQL pura e fecha o cursor."""
    try:
        conn = pyodbc.connect(CONEXAO_ODBC)
        cursor = conn.cursor()
        cursor.execute(query, params)

        
        # Se for uma consulta SELECT
        if cursor.description:
            colunas = [coluna[0] for coluna in cursor.description]
            if fetch_all:
                linhas = cursor.fetchall()
                resultado = [dict(zip(colunas, linha)) for linha in linhas]
            else:
                linha = cursor.fetchone()
                resultado = dict(zip(colunas, linha)) if linha else None
            cursor.close()
            conn.close()
            return resultado
        
        # Se for INSERT, UPDATE, DELETE
        conn.commit()
        cursor.close()
        conn.close()
        return True
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro no banco de dados: {str(e)}")

@app.get("/")
def home():
    return {"status": "API funcionando."}

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

# Exibir estatísticas
@app.get("/api/admin/estatisticas")
def obter_estatisticas():
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

# Listar todas as traduções formatados para a tabela do Admin
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

# Incrementa consultas do termo
@app.post("/api/traducao/{id_traducao}/consultar")
def registrar_consulta(id_traducao: int):
    sql = """
        UPDATE organograma.estatisticas_termos 
        SET quantidade_consultas = quantidade_consultas + 1 
        WHERE id_traducao = ?;
    """
    executar_query(sql, (id_traducao,))
    return {"status": "Consulta registrada."}

# Rota pra cadastrar termo
@app.post("/api/admin/traducao")
def cadastrar_traducao(dados: NovoTermoSchema):
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

@app.post("/api/admin/categoria")
def cadastrar_categoria(dados: NovaCategoriaSchema):
    nome_limpo = dados.nome.strip()
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
            "mensagem": f"A categoria '{nome_limpo}' já existe no banco!"
        }

    return {
        "status": "sucesso",
        "mensagem": f"Categoria '{nome_limpo}' criada!",
        "id_categoria": resultado['id_categoria']
    }

@app.post("/api/admin/tag")
def cadastrar_tag(dados: NovaTagSchema):
    nome_limpo = dados.nome.strip()
    sql = """
        INSERT INTO organograma.tags (nome)
        VALUES (?)
        ON CONFLICT (nome) DO NOTHING
        RETURNING id_tag;
    """
    resultado = executar_query(sql, (nome_limpo,), fetch_all=False)

    if not resultado:
        return {
            "status": "existente",
            "mensagem": f"A tag '{nome_limpo}' já existe no banco!"
        }

    return {
        "status": "success",
        "mensagem": f"Tag '{nome_limpo}' criada!",
        "id_tag": resultado['id_tag']
    }

@app.post("/api/admin/tag/connect")
def conectar_tag(dados: NovaTermoTagsSchema):
    sql = """
        INSERT INTO organograma.termo_tags (id_traducao, id_tag)
        VALUES (?, ?)
        ON CONFLICT DO NOTHING;
    """

    executar_query(sql, (dados.id_traducao, dados.id_tag), fetch_all=False)

    return {
        "status": "success",
        "mensagem": f"Tag ID {dados.id_tag} conectada à tradução ID {dados.id_traducao}."
    }

@app.post("/api/admin/midias")
def cadastrar_midia(dados: NovaMidiaSchema):
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

@app.delete("/api/admin/traducao/{id_traducao}/deletar")
def deletar_traducao(id_traducao: int):
    try:
        # 1. Remove estatística associada primeiro (por causa da FK)
        executar_query("DELETE FROM organograma.estatisticas_termos WHERE id_traducao = ?;", (id_traducao,))
        
        # 2. Remove tags associadas
        executar_query("DELETE FROM organograma.termo_tags WHERE id_traducao = ?;", (id_traducao,))
        
        # 3. Remove a tradução principal
        executar_query("DELETE FROM organograma.termos_traducoes WHERE id_traducao = ?;", (id_traducao,))
        
        return {"status": "Sucesso", "mensagem": f"Tradução #{id_traducao} removida com sucesso!"}
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail="Não foi possível deletar a tradução."
        )

@app.delete("/api/admin/termopt/{id_termo_pt}/deletar")
def deletar_termo_pt(id_termo_pt: int):
    try:
        sql = """
            DELETE FROM organograma.termos_portugues
            WHERE id_termo_pt = ?
        """
        executar_query(sql, (id_termo_pt,), fetch_all=False)

        return {
            "status": "success",
            "mensagem": f"Termo ID {id_termo_pt} deletado."
        }

    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail="Não foi possível deletar: o termo está sendo utiliziado em uma ou mais traduções."
        )

@app.delete("/api/admin/termoakwe/{id_termo_akwe}/deletar")
def deletar_termo_akwe(id_termo_akwe: int):
    try:
        sql = """
            DELETE FROM organograma.termos_akwe
            WHERE id_termo_akwe = ?
        """
        executar_query(sql, (id_termo_akwe,), fetch_all=False)
        
        return {
            "status": "success",
            "mensagem": f"Termo Akwẽ ID {id_termo_akwe} deletado."
        }
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail="Não foi possível deletar: o termo está sendo utilziado em uma ou mais traduções."
        )

@app.delete("/api/admin/categorias/{id_categoria}/deletar")
def deletar_categoria(id_categoria: int):
    try:
        sql = """
            DELETE FROM organograma.categorias WHERE id_categoria = ?
            ON CONFLICT DO NOTHING;
        """

        executar_query(sql, (id_categoria,), fetch_all=False)

        return {
            "status": "success",
            "mensagem": f"Categoria ID {id_categoria} deletada."
        }

    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail="Não foi possível deletar: a categoria está sendo utilziado em uma ou mais traduções."
        )

@app.delete("/api/admin/midias/{id_midia}/deletar")
def deletar_midia(id_midia: int):
    try:
        sql = """
            DELETE FROM organograma.midias WHERE id_midia = ?
        """

        executar_query(sql, (id_midia,), fetch_all=False)

        return {
            "status": "success",
            "mensagem": f"Mídia ID {id_midia} deletada."
        }

    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail="Não foi possível deletar a midia."
        )

@app.delete("/api/admin/tag/{id_tag}/deletar")
def deletar_tag(id_tag: int):
    try:
        sql = """
            DELETE FROM organograma.tags WHERE id_tag = ?
            ON CONFLICT DO NOTHING;
        """

        executar_query(sql, (id_tag,), fetch_all=False)

        return {
            "status": "success",
            "mensagem": f"Tag ID {id_tag} deletada."
        }

    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail="Não foi possível deletar: a tag está sendo utilziado em uma ou mais relação de tradução com tag."
        )

@app.delete("/api/admin/tag/disconnect")
def desconectar_tag(dados: NovaTermoTagsSchema):
    try:
        sql = """
            DELETE FROM organograma.termo_tags
            WHERE id_traducao = ? AND id_tag = ?
        """

        executar_query(sql, (dados.id_traducao, dados.id_tag), fetch_all=False)

        return {
            "status": "success",
            "mensagem": f"Tag ID {dados.id_tag} desconectada da tradução ID {dados.id_traducao}."
        }

    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail="Não foi possível deletar a conexão de tag com tradução."
        )