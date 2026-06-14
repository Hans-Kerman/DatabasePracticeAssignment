from fastapi import APIRouter, Depends, HTTPException
from db import query, query_one, call_proc, pool
from schemas import BookIn, AddCopiesIn, ReviewIn
from auth import admin_required, reader_required

router = APIRouter(prefix="/api", tags=["books"])


@router.get("/categories")
def list_categories():
    return query("SELECT * FROM category ORDER BY category_id")


@router.get("/books")
def list_books(q: str | None = None, category_id: int | None = None):
    pat = f"%{q}%" if q else None
    sql = """
        SELECT b.*, COALESCE(array_agg(bc.category_id)
               FILTER (WHERE bc.category_id IS NOT NULL), '{}') AS category_ids
        FROM book b
        LEFT JOIN book_category bc ON bc.book_id = b.book_id
        WHERE (%s::text IS NULL OR b.title ILIKE %s
               OR b.isbn ILIKE %s OR b.author ILIKE %s)
          AND (%s::int IS NULL OR EXISTS (
               SELECT 1 FROM book_category x
               WHERE x.book_id = b.book_id AND x.category_id = %s))
        GROUP BY b.book_id ORDER BY b.book_id
    """
    return query(sql, [pat, pat, pat, pat, category_id, category_id])


@router.get("/books/{book_id}")
def get_book(book_id: int):
    b = query_one("SELECT * FROM book WHERE book_id=%s", [book_id])
    if not b:
        raise HTTPException(status_code=404, detail="书目不存在")
    b["categories"] = query(
        "SELECT c.* FROM book_category bc JOIN category c ON c.category_id=bc.category_id "
        "WHERE bc.book_id=%s ORDER BY c.category_id", [book_id])
    b["inventory"] = query_one(
        "SELECT total_copies, available_copies FROM v_book_inventory WHERE book_id=%s", [book_id])
    b["copies"] = query("SELECT * FROM book_copy WHERE book_id=%s ORDER BY copy_id", [book_id])
    b["reviews"] = query(
        "SELECT r.*, rd.name AS reader_name FROM review r JOIN reader rd ON rd.reader_id=r.reader_id "
        "WHERE r.book_id=%s ORDER BY r.review_time DESC", [book_id])
    return b


@router.post("/books", dependencies=[Depends(admin_required)])
def add_book(body: BookIn):
    with pool.connection() as conn, conn.transaction(), conn.cursor() as cur:
        cur.execute(
            "INSERT INTO book (isbn,title,author,publisher,pub_date,price) "
            "VALUES (%s,%s,%s,%s,%s,%s) RETURNING book_id",
            [body.isbn, body.title, body.author, body.publisher, body.pub_date, body.price])
        book_id = cur.fetchone()["book_id"]
        if body.category_ids:
            cur.executemany(
                "INSERT INTO book_category (book_id,category_id) VALUES (%s,%s)",
                [(book_id, c) for c in body.category_ids])
    return {"book_id": book_id}


@router.post("/books/{book_id}/copies", dependencies=[Depends(admin_required)])
def add_copies(book_id: int, body: AddCopiesIn):
    call_proc("CALL sp_add_book_copies(%s,%s,%s)", [book_id, body.count, body.location])
    return {"ok": True}


@router.post("/reviews", dependencies=[Depends(reader_required)])
def add_review(body: ReviewIn, user=Depends(reader_required)):
    reader_id = int(user["sub"])
    # trg_check_review_auth 会校验是否借阅过该书目
    call_proc(
        "INSERT INTO review (reader_id,book_id,score,content) VALUES (%s,%s,%s,%s)",
        [reader_id, body.book_id, body.score, body.content])
    return {"ok": True}
