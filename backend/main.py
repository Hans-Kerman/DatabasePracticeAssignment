from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from db import pool
from routers import auth, books, readers, circulation, stats


@asynccontextmanager
async def lifespan(_app: FastAPI):
    try:
        pool.open()
    except Exception as e:
        print(f"[warn] DB 未就绪: {e}")
    yield
    pool.close()


app = FastAPI(title="图书管理系统 API", version="0.1.0", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://127.0.0.1:5173"],
    allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

for r in (auth, books, readers, circulation, stats):
    app.include_router(r.router)


@app.get("/")
def root():
    return {"service": "library-api", "status": "ok"}


@app.get("/api/health")
def health():
    try:
        with pool.connection() as conn, conn.cursor() as cur:
            cur.execute("SELECT 1")
        return {"db": "ok"}
    except Exception as e:
        return {"db": "unavailable", "error": str(e).split("\n")[0]}
