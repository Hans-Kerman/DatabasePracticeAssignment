from fastapi import APIRouter, HTTPException
from schemas import AdminLogin, ReaderLogin
from auth import login_admin, login_reader

router = APIRouter(prefix="/api", tags=["auth"])


@router.post("/login/admin")
def admin_login(body: AdminLogin):
    token = login_admin(body.username, body.password)
    if not token:
        raise HTTPException(status_code=401, detail="管理员账号或密码错误")
    return {"token": token, "role": "admin"}


@router.post("/login/reader")
def reader_login(body: ReaderLogin):
    res = login_reader(body.card_number)
    if not res:
        raise HTTPException(status_code=401, detail="读者证号不存在或已注销")
    token, reader_id = res
    return {"token": token, "role": "reader", "reader_id": reader_id}
