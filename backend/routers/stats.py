from fastapi import APIRouter, Depends
from db import query
from auth import admin_required

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
def borrowing():
    return query("SELECT * FROM v_reader_borrowing ORDER BY due_date")
