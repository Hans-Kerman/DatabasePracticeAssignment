from fastapi import APIRouter, Depends
from db import query, call_proc
from schemas import BorrowIn, ReturnIn, ReservationIn
from auth import admin_required, reader_required

router = APIRouter(prefix="/api", tags=["circulation"])


@router.post("/lend/borrow", dependencies=[Depends(admin_required)])
def borrow(body: BorrowIn):
    call_proc("CALL sp_borrow_book(%s,%s)", [body.reader_id, body.copy_id])
    return {"ok": True}


@router.post("/lend/return", dependencies=[Depends(admin_required)])
def return_book(body: ReturnIn):
    call_proc("CALL sp_return_book(%s)", [body.lend_id])
    return {"ok": True}


@router.post("/penalty/{penalty_id}/pay", dependencies=[Depends(admin_required)])
def pay_penalty(penalty_id: int):
    call_proc("CALL sp_pay_penalty(%s)", [penalty_id])
    return {"ok": True}


_LEND_JOIN = (
    "SELECT l.lend_id,l.reader_id,r.name AS reader_name,l.copy_id,b.title,c.location,"
    "l.borrow_date,l.due_date,l.renew_count "
    "FROM lend_record l JOIN reader r ON r.reader_id=l.reader_id "
    "JOIN book_copy c ON c.copy_id=l.copy_id JOIN book b ON b.book_id=c.book_id")


@router.get("/lend/active")
def active_lends(reader_id: int | None = None, user=Depends(reader_required)):
    if user["role"] == "reader":
        reader_id = int(user["sub"])
    if reader_id:
        return query(_LEND_JOIN + " WHERE l.return_date IS NULL AND l.reader_id=%s ORDER BY l.due_date", [reader_id])
    return query(_LEND_JOIN + " WHERE l.return_date IS NULL ORDER BY l.due_date")


_PENALTY_JOIN = (
    "SELECT p.penalty_id,p.lend_id,p.reader_id,r.name AS reader_name,p.amount,p.status,p.pay_time,b.title AS book_title "
    "FROM penalty p JOIN reader r ON r.reader_id=p.reader_id "
    "JOIN lend_record l ON l.lend_id=p.lend_id "
    "JOIN book_copy c ON c.copy_id=l.copy_id JOIN book b ON b.book_id=c.book_id")


@router.get("/penalties")
def list_penalties(reader_id: int | None = None, user=Depends(reader_required)):
    if user["role"] == "reader":
        reader_id = int(user["sub"])
    return query(
        _PENALTY_JOIN + " WHERE (%s::int IS NULL OR p.reader_id=%s) ORDER BY p.status, p.penalty_id",
        [reader_id, reader_id])


@router.post("/reservations", dependencies=[Depends(reader_required)])
def add_reservation(body: ReservationIn, user=Depends(reader_required)):
    reader_id = int(user["sub"])
    call_proc("INSERT INTO reservation (reader_id,book_id) VALUES (%s,%s)", [reader_id, body.book_id])
    return {"ok": True}


@router.get("/reservations", dependencies=[Depends(admin_required)])
def list_reservations():
    return query(
        "SELECT res.*, r.name AS reader_name, b.title AS book_title "
        "FROM reservation res JOIN reader r ON r.reader_id=res.reader_id "
        "JOIN book b ON b.book_id=res.book_id ORDER BY res.res_id")
