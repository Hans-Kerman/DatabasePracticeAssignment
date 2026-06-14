from fastapi import APIRouter, Depends, HTTPException
from psycopg.errors import DatabaseError
from db import query, query_one
from schemas import ReaderIn
from auth import admin_required, reader_required

router = APIRouter(prefix="/api", tags=["readers"])


@router.get("/readers", dependencies=[Depends(admin_required)])
def list_readers(q: str | None = None):
    pat = f"%{q}%" if q else None
    return query(
        "SELECT * FROM reader WHERE (%s::text IS NULL OR name ILIKE %s OR card_number ILIKE %s) "
        "ORDER BY reader_id", [pat, pat, pat])


@router.get("/readers/me")
def me(user=Depends(reader_required)):
    if user["role"] == "reader":
        r = query_one(
            "SELECT reader_id,name,card_number,phone,valid_until,status FROM reader WHERE reader_id=%s",
            [int(user["sub"])])
        if not r:
            raise HTTPException(status_code=404, detail="读者不存在")
        return r
    return {"role": "admin", "name": "管理员"}


@router.post("/readers", dependencies=[Depends(admin_required)])
def add_reader(body: ReaderIn):
    try:
        r = query_one(
            "INSERT INTO reader (name,card_number,phone,valid_until) VALUES (%s,%s,%s,%s) RETURNING reader_id",
            [body.name, body.card_number, body.phone, body.valid_until])
    except DatabaseError as e:
        raise HTTPException(status_code=400, detail=str(e).split("\n")[0].strip())
    return {"reader_id": r["reader_id"] if r else None}
