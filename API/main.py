import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional
import jwt
import psycopg2
from psycopg2.extras import RealDictCursor

from dotenv import load_dotenv
from fastapi import (
    APIRouter,
    Depends,
    FastAPI,
    HTTPException,
    Query,
    Request,
    status,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field
from pwdlib import PasswordHash
from jwt.exceptions import InvalidTokenError
import asyncio
import time
from collections import defaultdict
from threading import Lock

# ============================================================
# PROTEÇÃO CONTRA BRUTE FORCE
# ============================================================
#region

LOGIN_MAX_TENTATIVAS = 5
LOGIN_JANELA_SEGUNDOS = 300       # 5 minutos
LOGIN_BLOQUEIO_SEGUNDOS = 3600     # 1 hora

_login_lock = Lock()

_login_falhas = defaultdict(list)
_login_bloqueios = {}

def obter_identificador_cliente(
    request: Request,
    username: str,
) -> str:
    ip = (
        request.client.host
        if request.client
        else "ip-desconhecido"
    )

    return f"{ip.lower()}:{username.strip().lower()}"


def verificar_bloqueio_login(chave: str):
    agora = time.time()

    with _login_lock:
        bloqueado_ate = _login_bloqueios.get(chave, 0)

        if bloqueado_ate > agora:
            restante = int(bloqueado_ate - agora)

            raise HTTPException(
                status_code=429,
                detail=(
                    "Muitas tentativas de login. "
                    f"Tente novamente em aproximadamente "
                    f"{restante} segundo(s)."
                ),
                headers={
                    "Retry-After": str(restante)
                },
            )

        tentativas = _login_falhas.get(chave, [])

        tentativas_validas = [
            timestamp
            for timestamp in tentativas
            if agora - timestamp < LOGIN_JANELA_SEGUNDOS
        ]

        _login_falhas[chave] = tentativas_validas


def registrar_falha_login(chave: str):
    agora = time.time()

    with _login_lock:
        tentativas = _login_falhas.get(chave, [])

        tentativas_validas = [
            timestamp
            for timestamp in tentativas
            if agora - timestamp < LOGIN_JANELA_SEGUNDOS
        ]

        tentativas_validas.append(agora)
        _login_falhas[chave] = tentativas_validas

        if len(tentativas_validas) >= LOGIN_MAX_TENTATIVAS:
            _login_bloqueios[chave] = (
                agora + LOGIN_BLOQUEIO_SEGUNDOS
            )

            _login_falhas.pop(chave, None)


def limpar_falhas_login(chave: str):
    with _login_lock:
        _login_falhas.pop(chave, None)
        _login_bloqueios.pop(chave, None)

#endregion

# ============================================================
# CONFIGURAÇÃO
# ============================================================
#region

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent
INDEX_FILE = BASE_DIR / "index.html"

DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "postgres")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")

JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")

try:
    ACCESS_TOKEN_EXPIRE_MINUTES = int(
        os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "120")
    )
except ValueError:
    ACCESS_TOKEN_EXPIRE_MINUTES = 120

if not DB_USER:
    raise RuntimeError("DB_USER não foi configurado no .env.")

if not DB_PASSWORD:
    raise RuntimeError("DB_PASSWORD não foi configurado no .env.")

if not JWT_SECRET_KEY:
    raise RuntimeError("JWT_SECRET_KEY não foi configurado no .env.")

if len(JWT_SECRET_KEY.encode("utf-8")) < 32:
    raise RuntimeError(
        "JWT_SECRET_KEY deve possuir pelo menos 32 bytes."
    )

password_hash = PasswordHash.recommended()
security = HTTPBearer(auto_error=False)

#endregion

# ============================================================
# APLICAÇÃO
# ============================================================
#region
app = FastAPI(
    title="API - Dicionário Akwẽ",
    description="Backend RESTful para gerenciamento do Dicionário Akwẽ-Xerente",
    version="2.0.0",
)


origins_config = os.getenv(
    "FRONTEND_ORIGINS",
    "http://127.0.0.1:8000,http://localhost:8000",
)

ALLOWED_ORIGINS = [
    origin.strip()
    for origin in origins_config.split(",")
    if origin.strip()
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=[
        "Accept",
        "Content-Type",
        "Authorization",
        "ngrok-skip-browser-warning",
    ],
)

#endregion

# ============================================================
# SCHEMAS
# ============================================================
#region

class LoginSchema(BaseModel):
    username: str = Field(min_length=1, max_length=100)
    password: str = Field(min_length=1)


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


class ClarezaUpdateSchema(BaseModel):
    nivel_clareza: int = Field(ge=1, le=5)

#endregion

# ============================================================
# BANCO DE DADOS (CONEXÃO PSYCOPG2)
# ============================================================
#region

def criar_conexao():
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        sslmode="require"
    )

def executar_query(
    query: str,
    params: tuple = (),
    fetch_all: bool = True,
):
    conn = None
    cursor = None

    try:
        conn = criar_conexao()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Converte o '?' do pyodbc para '%s' do psycopg2 automaticamente
        query_convertida = query.replace("?", "%s")
        cursor.execute(query_convertida, params)

        resultado = None
        
        if cursor.description:
            if fetch_all:
                linhas = cursor.fetchall()
                resultado = [dict(linha) for linha in linhas]
            else:
                linha = cursor.fetchone()
                resultado = dict(linha) if linha else None
        else:
            resultado = cursor.rowcount
        
        conn.commit()
        return resultado

    except HTTPException:
        raise

    except Exception as exc:
        if conn:
            conn.rollback()

        raise HTTPException(
            status_code=500,
            detail=f"Erro no banco de dados: {str(exc)}",
        )

    finally:
        if cursor:
            cursor.close()

        if conn:
            conn.close()

#endregion

# ============================================================
# AUTENTICAÇÃO E AUTORIZAÇÃO
# ============================================================
#region 

def criar_access_token(usuario: dict) -> str:
    agora = datetime.now(timezone.utc)

    expiracao = agora + timedelta(
        minutes=ACCESS_TOKEN_EXPIRE_MINUTES
    )

    payload = {
        "sub": str(usuario["id_usuario"]),
        "username": usuario["username"],
        "perfil": usuario["perfil"],
        "iat": agora,
        "exp": expiracao,
    }

    return jwt.encode(
        payload,
        JWT_SECRET_KEY,
        algorithm=JWT_ALGORITHM,
    )


def buscar_usuario_por_username(username: str):
    sql = """
        SELECT
            id_usuario,
            username,
            email,
            senha_hash,
            perfil,
            ativo,
            criado_em
        FROM public.usuarios
        WHERE username = ?;
    """

    return executar_query(
        sql,
        (username,),
        fetch_all=False,
    )


def buscar_usuario_por_id(id_usuario: int):
    sql = """
        SELECT
            id_usuario,
            username,
            email,
            perfil,
            ativo,
            criado_em
        FROM public.usuarios
        WHERE id_usuario = ?;
    """

    return executar_query(
        sql,
        (id_usuario,),
        fetch_all=False,
    )


def usuario_publico(usuario: dict):
    return {
        "id_usuario": usuario["id_usuario"],
        "username": usuario["username"],
        "email": usuario.get("email"),
        "perfil": usuario["perfil"],
        "ativo": usuario["ativo"],
        "criado_em": usuario.get("criado_em"),
    }


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
):
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token de autenticação não informado.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Esquema de autenticação inválido.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = credentials.credentials

    try:
        payload = jwt.decode(
            token,
            JWT_SECRET_KEY,
            algorithms=[JWT_ALGORITHM],
        )

        subject = payload.get("sub")

        if not subject:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token sem usuário.",
                headers={"WWW-Authenticate": "Bearer"},
            )

        usuario = buscar_usuario_por_id(int(subject))

        if not usuario:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Usuário não encontrado.",
                headers={"WWW-Authenticate": "Bearer"},
            )

        if not usuario["ativo"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Usuário desativado.",
            )

        return usuario

    except HTTPException:
        raise

    except (InvalidTokenError, ValueError, TypeError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido ou expirado.",
            headers={"WWW-Authenticate": "Bearer"},
        )


def get_current_admin_user(
    usuario: dict = Depends(get_current_user),
):
    if usuario["perfil"] != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acesso permitido somente para administradores.",
        )

    return usuario

#endregion

# ============================================================
# ROTAS PÚBLICAS E AUTENTICAÇÃO
# ============================================================
#region

@app.get("/", include_in_schema=False)
def home():
    if not INDEX_FILE.exists():
        raise HTTPException(
            status_code=404,
            detail="Arquivo index.html não encontrado.",
        )

    return FileResponse(INDEX_FILE)


@app.get("/api/health")
def health():
    return {
        "status": "online",
        "service": "AkweAPI",
    }


@app.post("/api/auth/login")
def login(
    dados: LoginSchema,
    request: Request,
):
    chave = obter_identificador_cliente(
        request,
        dados.username,
    )

    verificar_bloqueio_login(chave)

    usuario = buscar_usuario_por_username(
        dados.username
    )

    senha_valida = False

    if usuario and usuario["ativo"]:
        senha_valida = password_hash.verify(
            dados.password,
            usuario["senha_hash"],
        )

    if not usuario or not usuario["ativo"] or not senha_valida:
        registrar_falha_login(chave)

        raise HTTPException(
            status_code=401,
            detail="Usuário ou senha inválidos.",
        )

    limpar_falhas_login(chave)

    token = criar_access_token(usuario)

    return {
        "access_token": token,
        "token_type": "bearer",
        "expires_in": ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        "usuario": usuario_publico(usuario),
    }


@app.get("/api/auth/me")
def auth_me(
    usuario: dict = Depends(get_current_user),
):
    return {
        "usuario": usuario_publico(usuario),
    }


@app.get("/api/search")
def buscar_termo(
    q: Optional[str] = Query(None),
):
    if not q or not q.strip():
        return {
            "resultados": [],
            "total": 0,
        }

    termo_busca = f"%{q.lower().strip()}%"

    sql = """
        SELECT
            t.id_traducao,
            tp.texto_portugues,
            ta.texto_akwe,
            ta.raiz_gramatical,
            c.nome AS categoria,
            t.explicacao_contexto
        FROM public.termos_traducoes t
        INNER JOIN public.termos_portugues tp
            ON t.id_termo_pt = tp.id_termo_pt
        INNER JOIN public.termos_akwe ta
            ON t.id_termo_akwe = ta.id_termo_akwe
        INNER JOIN public.categorias c
            ON t.id_categoria = c.id_categoria
        WHERE LOWER(tp.texto_portugues) LIKE ?
           OR LOWER(ta.texto_akwe) LIKE ?
           OR LOWER(COALESCE(ta.raiz_gramatical, '')) LIKE ?
        ORDER BY t.id_traducao ASC;
    """

    resultados = executar_query(
        sql,
        (termo_busca, termo_busca, termo_busca),
    )

    return {
        "busca": q,
        "total": len(resultados),
        "dados": resultados,
    }


@app.get("/api/traducoes")
def read_traducoes():
    sql = """
        SELECT *
        FROM public.termos_traducoes
        ORDER BY id_traducao ASC;
    """

    return {
        "termos_traducoes": executar_query(sql),
    }


@app.get("/api/categorias")
def read_categorias():
    return {
        "categorias": executar_query(
            "SELECT * FROM public.categorias ORDER BY id_categoria;"
        ),
    }


@app.get("/api/midias")
def read_midias():
    return {
        "midias": executar_query(
            "SELECT * FROM public.midias ORDER BY id_midia ASC;"
        ),
    }


@app.get("/api/tags")
def read_tags():
    return {
        "tags": executar_query(
            "SELECT * FROM public.tags ORDER BY nome;"
        ),
    }


@app.get("/api/termo-tags")
def read_termotags():
    return {
        "termo_tags": executar_query(
            "SELECT * FROM public.termo_tags;"
        ),
    }


@app.get("/api/termos-akwe")
def read_termos_akwe():
    return {
        "termos_akwe": executar_query(
            """
            SELECT *
            FROM public.termos_akwe
            ORDER BY texto_akwe;
            """
        ),
    }


@app.get("/api/termos-portugues")
def read_termos_pt():
    return {
        "termos_portugues": executar_query(
            """
            SELECT *
            FROM public.termos_portugues
            ORDER BY texto_portugues;
            """
        ),
    }


@app.patch("/api/traducoes/{id_traducao}/consultar")
def registrar_consulta(id_traducao: int):
    resultado = executar_query(
        """
        SELECT public.registrar_consulta(?)
        """,
        (id_traducao,),
        fetch_all=False,
    )

    if not resultado:
        raise HTTPException(
            status_code=404,
            detail="Estatística não encontrada.",
        )

    return {
        "status": "success",
        "mensagem": "Consulta registrada.",
    }


@app.patch("/api/traducoes/{id_traducao}/clareza")
def atualizar_clareza(id_traducao: int, dados: ClarezaUpdateSchema):
    # Verifica se já existe registro de estatística para esta tradução
    sql_check = "SELECT id_estatistica FROM public.estatisticas_termos WHERE id_traducao = %s;"
    res = executar_query(sql_check, (id_traducao,), fetch_all=False)
    
    if res:
        sql_update = """
            UPDATE public.estatisticas_termos
            SET nivel_clareza = %s
            WHERE id_traducao = %s
            RETURNING id_estatistica;
        """
        executar_query(sql_update, (dados.nivel_clareza, id_traducao), fetch_all=False)
    else:
        sql_insert = """
            INSERT INTO public.estatisticas_termos 
                (id_traducao, nivel_clareza, quantidade_consultas, reproducoes_audio, tempo_retencao_segundos)
            VALUES (%s, %s, 0, 0, 0)
            RETURNING id_estatistica;
        """
        executar_query(sql_insert, (id_traducao, dados.nivel_clareza), fetch_all=False)
        
    return {
        "status": "success",
        "mensagem": "Nível de clareza atualizado com sucesso."
    }


@app.get("/api/sync/meta")
def obter_metadados_sync():
    sql = """
        SELECT 
            COUNT(t.id_traducao) AS total_registros,
            MAX(t.id_traducao) AS max_id,
            MAX(t.atualizado_em) AS ultima_atualizacao
        FROM public.termos_traducoes t;
    """
    resultado = executar_query(sql, fetch_all=False)
    
    # Converte o datetime do Python para string ISO se existir
    if resultado and resultado.get("ultima_atualizacao"):
        resultado["ultima_atualizacao"] = resultado["ultima_atualizacao"].isoformat()
        
    return resultado or {"total_registros": 0, "max_id": 0, "ultima_atualizacao": None}


@app.get("/api/sync")
def sincronizar_palavras():
    sql = """
        SELECT 
            t.id_traducao,
            ta.texto_akwe AS akwe,
            tp.texto_portugues AS portugues,
            t.explicacao_contexto AS significado,
            MAX(CASE WHEN m.tipo = 'audio' THEN m.url_arquivo END) AS audio_url,
            MAX(CASE WHEN m.tipo IN ('imagem', 'video') THEN m.url_arquivo END) AS media_url,
            COALESCE(ARRAY_AGG(DISTINCT tg.nome) FILTER (WHERE tg.nome IS NOT NULL), ARRAY[]::VARCHAR[]) AS tags,
            MAX(e.nivel_clareza) AS nivel_clareza,
            t.atualizado_em
        FROM public.termos_traducoes t
        INNER JOIN public.termos_portugues tp
            ON t.id_termo_pt = tp.id_termo_pt
        INNER JOIN public.termos_akwe ta
            ON t.id_termo_akwe = ta.id_termo_akwe
        LEFT JOIN public.midias m
            ON t.id_traducao = m.id_traducao
        LEFT JOIN public.termo_tags tt
            ON t.id_traducao = tt.id_traducao
        LEFT JOIN public.tags tg
            ON tt.id_tag = tg.id_tag
        LEFT JOIN public.estatisticas_termos e
            ON t.id_traducao = e.id_traducao
        GROUP BY 
            t.id_traducao,
            ta.texto_akwe,
            tp.texto_portugues,
            t.explicacao_contexto,
            t.atualizado_em
        ORDER BY t.id_traducao ASC;
    """
    
    resultados = executar_query(sql, fetch_all=True)
    
    # Converte o datetime do Python para string ISO em cada registro
    for row in resultados:
        if row.get("atualizado_em"):
            row["atualizado_em"] = row["atualizado_em"].isoformat()
            
    return resultados

#endregion

# ============================================================
# ROUTER ADMINISTRATIVO
# ============================================================
#region

admin_router = APIRouter(
    prefix="/api/admin",
    dependencies=[Depends(get_current_admin_user)],
)


@admin_router.get("/estatisticas/overview")
def overview_estatisticas():
    sql = """
        SELECT
            COUNT(DISTINCT t.id_traducao) AS total_traducoes,
            COALESCE(SUM(e.quantidade_consultas), 0)
                AS total_consultas,
            COALESCE(SUM(e.reproducoes_audio), 0)
                AS total_audios_ouvidos,
            ROUND(AVG(e.nivel_clareza), 2)
                AS media_nivel_clareza
        FROM public.termos_traducoes t
        LEFT JOIN public.estatisticas_termos e
            ON t.id_traducao = e.id_traducao;
    """

    return {
        "estatisticas": executar_query(
            sql,
            fetch_all=False,
        ),
    }


@admin_router.get("/estatisticas")
def read_estatisticas():
    return {
        "estatisticas": executar_query(
            """
            SELECT *
            FROM public.estatisticas_termos
            ORDER BY id_estatistica ASC;
            """
        ),
    }


@admin_router.get("/traducoes")
def listar_traducoes_admin(
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=200),
    busca: Optional[str] = Query(None),
):
    filtros = []
    params = []

    if busca and busca.strip():
        termo = f"%{busca.strip().lower()}%"

        filtros.append(
            """
            (
                LOWER(tp.texto_portugues) LIKE ?
                OR LOWER(ta.texto_akwe) LIKE ?
                OR LOWER(COALESCE(ta.raiz_gramatical, '')) LIKE ?
                OR LOWER(COALESCE(t.explicacao_contexto, '')) LIKE ?
            )
            """
        )

        params.extend([
            termo,
            termo,
            termo,
            termo,
        ])

    where_sql = ""

    if filtros:
        where_sql = "WHERE " + " AND ".join(filtros)

    count_sql = f"""
        SELECT COUNT(DISTINCT t.id_traducao) AS total
        FROM public.termos_traducoes t
        INNER JOIN public.termos_portugues tp
            ON t.id_termo_pt = tp.id_termo_pt
        INNER JOIN public.termos_akwe ta
            ON t.id_termo_akwe = ta.id_termo_akwe
        {where_sql};
    """

    total_resultado = executar_query(
        count_sql,
        tuple(params),
        fetch_all=False,
    )

    total_registros = int(
        total_resultado["total"]
        if total_resultado
        else 0
    )

    total_paginas = (
        (total_registros + limit - 1) // limit
        if total_registros
        else 0
    )

    offset = (page - 1) * limit

    sql = f"""
        SELECT
            t.id_traducao,
            tp.texto_portugues,
            ta.texto_akwe,
            ta.raiz_gramatical,
            c.nome AS categoria,
            t.explicacao_contexto,
            STRING_AGG(DISTINCT tg.nome, ', ')
                AS tags,
            STRING_AGG(DISTINCT m.url_arquivo, ', ')
                AS midias
        FROM public.termos_traducoes t
        INNER JOIN public.termos_portugues tp
            ON t.id_termo_pt = tp.id_termo_pt
        INNER JOIN public.termos_akwe ta
            ON t.id_termo_akwe = ta.id_termo_akwe
        INNER JOIN public.categorias c
            ON t.id_categoria = c.id_categoria
        LEFT JOIN public.termo_tags tt
            ON t.id_traducao = tt.id_traducao
        LEFT JOIN public.tags tg
            ON tt.id_tag = tg.id_tag
        LEFT JOIN public.midias m
            ON t.id_traducao = m.id_traducao
        {where_sql}
        GROUP BY
            t.id_traducao,
            tp.texto_portugues,
            ta.texto_akwe,
            ta.raiz_gramatical,
            c.nome,
            t.explicacao_contexto
        ORDER BY t.id_traducao ASC
        LIMIT ? OFFSET ?;
    """

    dados = executar_query(
        sql,
        tuple(params + [limit, offset]),
    )

    return {
        "termos": dados,
        "paginacao": {
            "pagina_atual": page,
            "limite": limit,
            "total_registros": total_registros,
            "total_paginas": total_paginas,
            "tem_anterior": page > 1,
            "tem_proxima": page < total_paginas,
        },
    }


@admin_router.post("/traducoes", status_code=201)
def create_traducao(dados: TraducaoCreateSchema):
    conn = None
    cursor = None

    try:
        conn = criar_conexao()
        cursor = conn.cursor()

        cursor.execute(
            """
            SELECT id_termo_pt
            FROM public.termos_portugues
            WHERE texto_portugues = %s;
            """,
            (dados.texto_portugues,),
        )

        row_pt = cursor.fetchone()

        if row_pt:
            id_termo_pt = row_pt[0]
        else:
            cursor.execute(
                """
                INSERT INTO public.termos_portugues
                    (texto_portugues)
                VALUES (%s)
                RETURNING id_termo_pt;
                """,
                (dados.texto_portugues,),
            )

            id_termo_pt = cursor.fetchone()[0]

        cursor.execute(
            """
            SELECT id_termo_akwe
            FROM public.termos_akwe
            WHERE texto_akwe = %s;
            """,
            (dados.texto_akwe,),
        )

        row_akwe = cursor.fetchone()

        if row_akwe:
            id_termo_akwe = row_akwe[0]

            if dados.raiz_gramatical:
                cursor.execute(
                    """
                    UPDATE public.termos_akwe
                    SET raiz_gramatical = %s
                    WHERE id_termo_akwe = %s;
                    """,
                    (
                        dados.raiz_gramatical,
                        id_termo_akwe,
                    ),
                )
        else:
            cursor.execute(
                """
                INSERT INTO public.termos_akwe
                    (texto_akwe, raiz_gramatical)
                VALUES (%s, %s)
                RETURNING id_termo_akwe;
                """,
                (
                    dados.texto_akwe,
                    dados.raiz_gramatical,
                ),
            )

            id_termo_akwe = cursor.fetchone()[0]

        cursor.execute(
            """
            INSERT INTO public.termos_traducoes
                (
                    id_termo_pt,
                    id_termo_akwe,
                    id_categoria,
                    explicacao_contexto
                )
            VALUES (%s, %s, %s, %s)
            RETURNING id_traducao;
            """,
            (
                id_termo_pt,
                id_termo_akwe,
                dados.id_categoria,
                dados.explicacao_contexto,
            ),
        )

        id_traducao = cursor.fetchone()[0]

        cursor.execute(
            """
            INSERT INTO public.estatisticas_termos
                (
                    id_traducao,
                    quantidade_consultas,
                    reproducoes_audio,
                    tempo_retencao_segundos
                )
            VALUES (%s, 0, 0, 0);
            """,
            (id_traducao,),
        )

        conn.commit()

        return {
            "status": "success",
            "mensagem": "Tradução cadastrada com sucesso.",
            "id_traducao": id_traducao,
        }

    except Exception as exc:
        if conn:
            conn.rollback()

        raise HTTPException(
            status_code=400,
            detail=f"Erro ao salvar termo: {str(exc)}",
        )

    finally:
        if cursor:
            cursor.close()

        if conn:
            conn.close()


@admin_router.put("/traducoes/{id_traducao}")
def update_traducao(
    id_traducao: int,
    dados: TraducaoUpdateSchema,
):
    resultado = executar_query(
        """
        UPDATE public.termos_traducoes
        SET
            id_categoria = ?,
            explicacao_contexto = ?
        WHERE id_traducao = ?
        RETURNING id_traducao;
        """,
        (
            dados.id_categoria,
            dados.explicacao_contexto,
            id_traducao,
        ),
        fetch_all=False,
    )

    if not resultado:
        raise HTTPException(
            status_code=404,
            detail="Tradução não encontrada.",
        )

    return {
        "status": "success",
        "mensagem": "Tradução atualizada com sucesso.",
    }


@admin_router.delete("/traducoes/{id_traducao}")
def delete_traducao(id_traducao: int):
    executar_query(
        """
        DELETE FROM public.estatisticas_termos
        WHERE id_traducao = ?;
        """,
        (id_traducao,),
    )

    executar_query(
        """
        DELETE FROM public.termo_tags
        WHERE id_traducao = ?;
        """,
        (id_traducao,),
    )

    executar_query(
        """
        DELETE FROM public.midias
        WHERE id_traducao = ?;
        """,
        (id_traducao,),
    )

    resultado = executar_query(
        """
        DELETE FROM public.termos_traducoes
        WHERE id_traducao = ?
        RETURNING id_traducao;
        """,
        (id_traducao,),
        fetch_all=False,
    )

    if not resultado:
        raise HTTPException(
            status_code=404,
            detail="Tradução não encontrada.",
        )

    return {
        "status": "success",
        "mensagem": "Tradução removida com sucesso.",
    }


@admin_router.post("/categorias", status_code=201)
def create_categoria(dados: CategoriaSchema):
    resultado = executar_query(
        """
        INSERT INTO public.categorias (nome)
        VALUES (?)
        ON CONFLICT (nome) DO NOTHING
        RETURNING id_categoria;
        """,
        (dados.nome,),
        fetch_all=False,
    )

    if not resultado:
        return {
            "status": "existente",
            "mensagem": "A categoria já existe.",
        }

    return {
        "status": "success",
        "id_categoria": resultado["id_categoria"],
    }


@admin_router.delete("/categorias/{id_categoria}")
def delete_categoria(id_categoria: int):
    resultado = executar_query(
        """
        DELETE FROM public.categorias
        WHERE id_categoria = ?
        RETURNING id_categoria;
        """,
        (id_categoria,),
        fetch_all=False,
    )

    if not resultado:
        raise HTTPException(
            status_code=404,
            detail="Categoria não encontrada ou está em uso.",
        )

    return {
        "status": "success",
        "mensagem": "Categoria removida.",
    }


@admin_router.post("/tags", status_code=201)
def create_tag(dados: TagSchema):
    resultado = executar_query(
        """
        INSERT INTO public.tags (nome)
        VALUES (?)
        ON CONFLICT (nome) DO NOTHING
        RETURNING id_tag;
        """,
        (dados.nome,),
        fetch_all=False,
    )

    if not resultado:
        return {
            "status": "existente",
            "mensagem": "A tag já existe.",
        }

    return {
        "status": "success",
        "id_tag": resultado["id_tag"],
    }


@admin_router.delete("/tags/{id_tag}")
def delete_tag(id_tag: int):
    resultado = executar_query(
        """
        DELETE FROM public.tags
        WHERE id_tag = ?
        RETURNING id_tag;
        """,
        (id_tag,),
        fetch_all=False,
    )

    if not resultado:
        raise HTTPException(
            status_code=404,
            detail="Tag não encontrada ou está em uso.",
        )

    return {
        "status": "success",
        "mensagem": "Tag removida.",
    }


@admin_router.post("/termo-tags", status_code=201)
def conectar_tag(dados: TermoTagsSchema):
    executar_query(
        """
        INSERT INTO public.termo_tags
            (id_traducao, id_tag)
        VALUES (?, ?)
        ON CONFLICT DO NOTHING;
        """,
        (
            dados.id_traducao,
            dados.id_tag,
        ),
    )

    return {
        "status": "success",
        "mensagem": "Tag vinculada com sucesso.",
    }


@admin_router.delete("/termo-tags/{id_traducao}/{id_tag}")
def desconectar_tag(
    id_traducao: int,
    id_tag: int,
):
    resultado = executar_query(
        """
        DELETE FROM public.termo_tags
        WHERE id_traducao = ?
          AND id_tag = ?
        RETURNING id_traducao;
        """,
        (
            id_traducao,
            id_tag,
        ),
        fetch_all=False,
    )

    if not resultado:
        raise HTTPException(
            status_code=404,
            detail="Vínculo não encontrado.",
        )

    return {
        "status": "success",
        "mensagem": "Tag desvinculada.",
    }


@admin_router.post("/midias", status_code=201)
def create_midia(dados: MidiaCreateSchema):
    resultado = executar_query(
        """
        INSERT INTO public.midias
            (tipo, url_arquivo, id_traducao)
        VALUES (?, ?, ?)
        RETURNING id_midia;
        """,
        (
            dados.tipo,
            dados.url_arquivo,
            dados.id_traducao,
        ),
        fetch_all=False,
    )

    return {
        "status": "success",
        "id_midia": resultado["id_midia"],
    }


@admin_router.put("/midias/{id_midia}")
def update_midia(
    id_midia: int,
    dados: MidiaUpdateSchema,
):
    resultado = executar_query(
        """
        UPDATE public.midias
        SET
            tipo = ?,
            url_arquivo = ?,
            id_traducao = ?
        WHERE id_midia = ?
        RETURNING id_midia;
        """,
        (
            dados.tipo,
            dados.url_arquivo,
            dados.id_traducao,
            id_midia,
        ),
        fetch_all=False,
    )

    if not resultado:
        raise HTTPException(
            status_code=404,
            detail="Mídia não encontrada.",
        )

    return {
        "status": "success",
        "mensagem": "Mídia atualizada.",
    }


@admin_router.delete("/midias/{id_midia}")
def delete_midia(id_midia: int):
    resultado = executar_query(
        """
        DELETE FROM public.midias
        WHERE id_midia = ?
        RETURNING id_midia;
        """,
        (id_midia,),
        fetch_all=False,
    )

    if not resultado:
        raise HTTPException(
            status_code=404,
            detail="Mídia não encontrada.",
        )

    return {
        "status": "success",
        "mensagem": "Mídia removida.",
    }


@admin_router.post("/termos-portugues", status_code=201)
def create_termo_pt(dados: TermoPtSchema):
    resultado = executar_query(
        """
        INSERT INTO public.termos_portugues
            (texto_portugues)
        VALUES (?)
        RETURNING id_termo_pt;
        """,
        (dados.texto_portugues,),
        fetch_all=False,
    )

    return {
        "status": "success",
        "id_termo_pt": resultado["id_termo_pt"],
    }


@admin_router.put("/termos-portugues/{id_termo_pt}")
def update_termo_pt(
    id_termo_pt: int,
    dados: TermoPtSchema,
):
    resultado = executar_query(
        """
        UPDATE public.termos_portugues
        SET texto_portugues = ?
        WHERE id_termo_pt = ?
        RETURNING id_termo_pt;
        """,
        (
            dados.texto_portugues,
            id_termo_pt,
        ),
        fetch_all=False,
    )

    if not resultado:
        raise HTTPException(
            status_code=404,
            detail="Termo português não encontrado.",
        )

    return {
        "status": "success",
        "mensagem": "Termo atualizado.",
    }


@admin_router.delete("/termos-portugues/{id_termo_pt}")
def delete_termo_pt(id_termo_pt: int):
    resultado = executar_query(
        """
        DELETE FROM public.termos_portugues
        WHERE id_termo_pt = ?
        RETURNING id_termo_pt;
        """,
        (id_termo_pt,),
        fetch_all=False,
    )

    if not resultado:
        raise HTTPException(
            status_code=404,
            detail="Termo não encontrado ou está em uso.",
        )

    return {
        "status": "success",
        "mensagem": "Termo removido.",
    }


@admin_router.post("/termos-akwe", status_code=201)
def create_termo_akwe(dados: TermoAkweSchema):
    resultado = executar_query(
        """
        INSERT INTO public.termos_akwe
            (texto_akwe, raiz_gramatical)
        VALUES (?, ?)
        RETURNING id_termo_akwe;
        """,
        (
            dados.texto_akwe,
            dados.raiz_gramatical,
        ),
        fetch_all=False,
    )

    return {
        "status": "success",
        "id_termo_akwe": resultado["id_termo_akwe"],
    }


@admin_router.put("/termos-akwe/{id_termo_akwe}")
def update_termo_akwe(
    id_termo_akwe: int,
    dados: TermoAkweSchema,
):
    resultado = executar_query(
        """
        UPDATE public.termos_akwe
        SET
            texto_akwe = ?,
            raiz_gramatical = ?
        WHERE id_termo_akwe = ?
        RETURNING id_termo_akwe;
        """,
        (
            dados.texto_akwe,
            dados.raiz_gramatical,
            id_termo_akwe,
        ),
        fetch_all=False,
    )

    if not resultado:
        raise HTTPException(
            status_code=404,
            detail="Termo Akwẽ não encontrado.",
        )

    return {
        "status": "success",
        "mensagem": "Termo Akwẽ atualizado.",
    }


@admin_router.delete("/termos-akwe/{id_termo_akwe}")
def delete_termo_akwe(id_termo_akwe: int):
    resultado = executar_query(
        """
        DELETE FROM public.termos_akwe
        WHERE id_termo_akwe = ?
        RETURNING id_termo_akwe;
        """,
        (id_termo_akwe,),
        fetch_all=False,
    )

    if not resultado:
        raise HTTPException(
            status_code=404,
            detail="Termo não encontrado ou está em uso.",
        )

    return {
        "status": "success",
        "mensagem": "Termo removido.",
    }


@admin_router.post("/estatisticas", status_code=201)
def create_estatistica(dados: EstatisticaCreateSchema):
    resultado = executar_query(
        """
        INSERT INTO public.estatisticas_termos
            (id_traducao)
        VALUES (?)
        RETURNING id_estatistica;
        """,
        (dados.id_traducao,),
        fetch_all=False,
    )

    return {
        "status": "success",
        "id_estatistica": resultado["id_estatistica"],
    }


@admin_router.put("/estatisticas/{id_estatistica}")
def update_estatistica(
    id_estatistica: int,
    dados: EstatisticaUpdateSchema,
):
    resultado = executar_query(
        """
        UPDATE public.estatisticas_termos
        SET
            id_traducao = ?,
            quantidade_consultas = ?,
            reproducoes_audio = ?,
            nivel_clareza = ?,
            tempo_retencao_segundos = ?
        WHERE id_estatistica = ?
        RETURNING id_estatistica;
        """,
        (
            dados.id_traducao,
            dados.quantidade_consultas,
            dados.reproducoes_audio,
            dados.nivel_clareza,
            dados.tempo_retencao_segundos,
            id_estatistica,
        ),
        fetch_all=False,
    )

    if not resultado:
        raise HTTPException(
            status_code=404,
            detail="Estatística não encontrada.",
        )

    return {
        "status": "success",
        "mensagem": "Estatística atualizada.",
    }


@admin_router.delete("/estatisticas/{id_estatistica}")
def delete_estatistica(id_estatistica: int):
    resultado = executar_query(
        """
        DELETE FROM public.estatisticas_termos
        WHERE id_estatistica = ?
        RETURNING id_estatistica;
        """,
        (id_estatistica,),
        fetch_all=False,
    )

    if not resultado:
        raise HTTPException(
            status_code=404,
            detail="Estatística não encontrada.",
        )

    return {
        "status": "success",
        "mensagem": "Estatística removida.",
    }

app.include_router(admin_router)

#endregion