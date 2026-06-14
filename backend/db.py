import os
from psycopg_pool import ConnectionPool
from psycopg.rows import dict_row
from psycopg.errors import DatabaseError
from fastapi import HTTPException
from dotenv import load_dotenv

load_dotenv()

_conninfo = " ".join([
    f"host={os.getenv('PG_HOST', '')}",
    f"port={os.getenv('PG_PORT', '5432')}",
    f"dbname={os.getenv('PG_DB', '')}",
    f"user={os.getenv('PG_USER', '')}",
    f"password={os.getenv('PG_PASSWORD', '')}",
])

# autocommit=True 才能调含 COMMIT 的存储过程；open=False 延迟连接，DB 没起也能启动服务
pool = ConnectionPool(
    _conninfo, min_size=1, max_size=10,
    kwargs={"autocommit": True, "row_factory": dict_row}, open=False,
)


def query(sql, params=None):
    with pool.connection() as conn, conn.cursor() as cur:
        cur.execute(sql, params or [])
        return cur.fetchall()


def query_one(sql, params=None):
    with pool.connection() as conn, conn.cursor() as cur:
        cur.execute(sql, params or [])
        return cur.fetchone()


def execute(sql, params=None):
    with pool.connection() as conn, conn.cursor() as cur:
        cur.execute(sql, params or [])
        return cur.rowcount


def call_proc(sql, params=None):
    # 调存储过程 / 触发器可能 RAISE，统一转 400
    try:
        with pool.connection() as conn, conn.cursor() as cur:
            cur.execute(sql, params or [])
    except DatabaseError as e:
        raise HTTPException(status_code=400, detail=str(e).split("\n")[0].strip())
