import time
import jwt
from fastapi import HTTPException, Header

SECRET = "library-demo-secret-please-change"
ADMIN_USER = "admin"
ADMIN_PASS = "admin123"
TOKEN_TTL = 24 * 3600


def issue(role, sub):
    payload = {"role": role, "sub": str(sub), "exp": int(time.time()) + TOKEN_TTL}
    return jwt.encode(payload, SECRET, algorithm="HS256")


def _bearer(authorization):
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="缺少认证凭证")
    try:
        return jwt.decode(authorization.split(" ", 1)[1], SECRET, algorithms=["HS256"])
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="无效或过期的登录凭证")


def admin_required(authorization: str | None = Header(None)):
    p = _bearer(authorization)
    if p.get("role") != "admin":
        raise HTTPException(status_code=403, detail="需要管理员权限")
    return p


def reader_required(authorization: str | None = Header(None)):
    p = _bearer(authorization)
    if p.get("role") not in ("reader", "admin"):
        raise HTTPException(status_code=403, detail="需要读者权限")
    return p


def login_admin(username, password):
    if username == ADMIN_USER and password == ADMIN_PASS:
        return issue("admin", username)
    return None


def login_reader(card_number):
    from db import query_one
    row = query_one("SELECT reader_id, status FROM reader WHERE card_number=%s", [card_number])
    if not row or row["status"] == "注销":
        return None
    return issue("reader", row["reader_id"]), row["reader_id"]
