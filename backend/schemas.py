from pydantic import BaseModel, Field


class AdminLogin(BaseModel):
    username: str
    password: str


class ReaderLogin(BaseModel):
    card_number: str


class BookIn(BaseModel):
    isbn: str
    title: str
    author: str | None = None
    publisher: str | None = None
    pub_date: str | None = None
    price: float | None = None
    category_ids: list[int] = []


class AddCopiesIn(BaseModel):
    count: int = Field(ge=1, le=1000)
    location: str | None = None


class ReaderIn(BaseModel):
    name: str
    card_number: str
    phone: str | None = None
    valid_until: str


class BorrowIn(BaseModel):
    reader_id: int
    copy_id: int


class ReturnIn(BaseModel):
    lend_id: int


class ReviewIn(BaseModel):
    book_id: int
    score: int = Field(ge=1, le=5)
    content: str | None = None


class ReservationIn(BaseModel):
    book_id: int
