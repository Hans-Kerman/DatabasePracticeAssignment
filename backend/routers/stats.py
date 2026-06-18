from fastapi import APIRouter, Depends
from db import query, query_one
from auth import admin_required, reader_required

router = APIRouter(prefix="/api/stats", tags=["stats"])


@router.get("/inventory")
def inventory():
    return query("SELECT * FROM v_book_inventory ORDER BY book_id")


@router.get("/reviews")
def reviews():
    return query("SELECT * FROM v_book_reviews ORDER BY book_id")


@router.get("/overdue", dependencies=[Depends(admin_required)])
def overdue():
    return query("SELECT * FROM v_overdue_alert ORDER BY overdue_days DESC")


@router.get("/borrowing")
def borrowing(user=Depends(reader_required)):
    if user["role"] == "reader":
        # 读者只能看自己的在借明细
        r = query_one("SELECT card_number FROM reader WHERE reader_id=%s", [int(user["sub"])])
        if r:
            return query(
                "SELECT * FROM v_reader_borrowing WHERE card_number=%s ORDER BY due_date",
                [r["card_number"]],
            )
        return []
    return query("SELECT * FROM v_reader_borrowing ORDER BY due_date")
