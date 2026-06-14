-- =====================================================================
-- 图书管理系统 - 完整建表脚本 (PostgreSQL)
-- 9张表 + 索引 + 角色 + 4视图 + 4存储过程 + 4触发器
-- 依据 docs/3物理结构设计和系统实现.md 落地
-- 可重复执行：脚本顶部自动清理旧对象
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. 清理（保证可重复执行）
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS v_book_inventory, v_reader_borrowing, v_overdue_alert, v_book_reviews;

DROP TRIGGER IF EXISTS trg_auto_penalty ON lend_record;
DROP TRIGGER IF EXISTS trg_freeze_reader ON penalty;
DROP TRIGGER IF EXISTS trg_check_borrow_limit ON lend_record;
DROP TRIGGER IF EXISTS trg_check_review_auth ON review;

DROP FUNCTION IF EXISTS trg_func_auto_penalty() CASCADE;
DROP FUNCTION IF EXISTS trg_func_freeze_reader() CASCADE;
DROP FUNCTION IF EXISTS trg_func_check_borrow_limit() CASCADE;
DROP FUNCTION IF EXISTS trg_func_check_review_auth() CASCADE;

DROP PROCEDURE IF EXISTS sp_borrow_book(INT, INT);
DROP PROCEDURE IF EXISTS sp_return_book(INT);
DROP PROCEDURE IF EXISTS sp_pay_penalty(INT);
DROP PROCEDURE IF EXISTS sp_add_book_copies(INT, INT, VARCHAR);

DROP TABLE IF EXISTS review CASCADE;
DROP TABLE IF EXISTS reservation CASCADE;
DROP TABLE IF EXISTS penalty CASCADE;
DROP TABLE IF EXISTS lend_record CASCADE;
DROP TABLE IF EXISTS book_copy CASCADE;
DROP TABLE IF EXISTS reader CASCADE;
DROP TABLE IF EXISTS book_category CASCADE;
DROP TABLE IF EXISTS category CASCADE;
DROP TABLE IF EXISTS book CASCADE;

-- ---------------------------------------------------------------------
-- 1. 建表（按外键依赖顺序）
-- ---------------------------------------------------------------------

-- 1.1 图书书目表 (SPU)
CREATE TABLE book (
    book_id    SERIAL PRIMARY KEY,
    isbn       VARCHAR(20) UNIQUE NOT NULL,
    title      VARCHAR(100) NOT NULL,
    author     VARCHAR(100),
    publisher  VARCHAR(100),
    pub_date   DATE,
    price      DECIMAL(8, 2)
);

-- 1.2 图书分类表
CREATE TABLE category (
    category_id SERIAL PRIMARY KEY,
    name        VARCHAR(50) NOT NULL,
    description TEXT
);

-- 1.3 书目-分类映射表 (M:N)
CREATE TABLE book_category (
    book_id     INT REFERENCES book(book_id) ON DELETE CASCADE,
    category_id INT REFERENCES category(category_id) ON DELETE CASCADE,
    PRIMARY KEY (book_id, category_id)
);

-- 1.4 读者信息表
CREATE TABLE reader (
    reader_id   SERIAL PRIMARY KEY,
    name        VARCHAR(50) NOT NULL,
    card_number VARCHAR(20) UNIQUE NOT NULL,
    phone       VARCHAR(20),
    valid_until DATE NOT NULL,
    status      VARCHAR(10) DEFAULT '正常'
        CHECK (status IN ('正常', '冻结', '注销'))
);

-- 1.5 馆藏单册表 (SKU)
CREATE TABLE book_copy (
    copy_id     SERIAL PRIMARY KEY,
    book_id     INT REFERENCES book(book_id) NOT NULL,
    location    VARCHAR(50),
    status      VARCHAR(10) DEFAULT '在馆'
        CHECK (status IN ('在馆', '已借出', '遗失', '破损')),
    create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 1.6 借阅记录表
CREATE TABLE lend_record (
    lend_id     SERIAL PRIMARY KEY,
    reader_id   INT REFERENCES reader(reader_id) NOT NULL,
    copy_id     INT REFERENCES book_copy(copy_id) NOT NULL,
    borrow_date DATE DEFAULT CURRENT_DATE,
    due_date    DATE NOT NULL,
    return_date DATE,
    renew_count INT DEFAULT 0
);

-- 1.7 逾期罚单表 (强依赖 lend_record)
CREATE TABLE penalty (
    penalty_id SERIAL PRIMARY KEY,
    lend_id    INT REFERENCES lend_record(lend_id) NOT NULL,
    reader_id  INT REFERENCES reader(reader_id) NOT NULL,
    amount     DECIMAL(8, 2) NOT NULL,
    status     VARCHAR(10) DEFAULT '未缴清'
        CHECK (status IN ('未缴清', '已缴清')),
    pay_time   TIMESTAMP
);

-- 1.8 预约排队表 (针对书目)
CREATE TABLE reservation (
    res_id   SERIAL PRIMARY KEY,
    reader_id INT REFERENCES reader(reader_id) NOT NULL,
    book_id   INT REFERENCES book(book_id) NOT NULL,
    res_date  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status    VARCHAR(10) DEFAULT '排队中'
        CHECK (status IN ('排队中', '已通知', '已取消', '已完成'))
);

-- 1.9 图书评价表
CREATE TABLE review (
    review_id   SERIAL PRIMARY KEY,
    reader_id   INT REFERENCES reader(reader_id) NOT NULL,
    book_id     INT REFERENCES book(book_id) NOT NULL,
    score       INT CHECK (score >= 1 AND score <= 5),
    content     TEXT,
    review_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------------
-- 2. 索引（物理设计：主键自带聚簇，此处补外键+高频查询索引）
-- ---------------------------------------------------------------------
CREATE INDEX idx_lend_reader   ON lend_record(reader_id);
CREATE INDEX idx_lend_copy     ON lend_record(copy_id);
CREATE INDEX idx_copy_book     ON book_copy(book_id);
CREATE INDEX idx_book_title    ON book(title);
CREATE INDEX idx_book_isbn     ON book(isbn);
CREATE INDEX idx_reader_card   ON reader(card_number);

-- ---------------------------------------------------------------------
-- 3. 安全性设计：角色与权限（RBAC）
-- ---------------------------------------------------------------------
DO $$ BEGIN CREATE ROLE role_admin;  EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE ROLE role_reader; EXCEPTION WHEN duplicate_object THEN NULL; END $$;

GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA public TO role_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO role_admin;

-- 读者：书目/分类/单册只读
GRANT SELECT ON book, category, book_category, book_copy TO role_reader;
-- 读者：评价/预约可读可写
GRANT SELECT, INSERT ON review, reservation TO role_reader;

-- 示例用户（密码可在实际部署时修改）
DO $$ BEGIN CREATE USER lib_admin1  WITH PASSWORD 'Admin@123'; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE USER stu_reader1 WITH PASSWORD 'Stu@123';   EXCEPTION WHEN duplicate_object THEN NULL; END $$;
GRANT role_admin  TO lib_admin1;
GRANT role_reader TO stu_reader1;

-- ---------------------------------------------------------------------
-- 4. 视图（4个）
-- ---------------------------------------------------------------------

-- 4.1 综合图书库存
CREATE VIEW v_book_inventory AS
SELECT
    b.book_id,
    b.isbn,
    b.title,
    b.author,
    COUNT(c.copy_id) AS total_copies,
    SUM(CASE WHEN c.status = '在馆' THEN 1 ELSE 0 END) AS available_copies
FROM book b
LEFT JOIN book_copy c ON b.book_id = c.book_id
GROUP BY b.book_id, b.isbn, b.title, b.author;

-- 4.2 读者当前在借明细
CREATE VIEW v_reader_borrowing AS
SELECT
    r.name AS reader_name,
    r.card_number,
    b.title AS book_title,
    c.location AS book_location,
    l.borrow_date,
    l.due_date,
    l.renew_count
FROM lend_record l
JOIN reader    r ON l.reader_id = r.reader_id
JOIN book_copy c ON l.copy_id   = c.copy_id
JOIN book      b ON c.book_id   = b.book_id
WHERE l.return_date IS NULL;

-- 4.3 超期违约警报
CREATE VIEW v_overdue_alert AS
SELECT
    l.lend_id,
    r.name AS reader_name,
    r.phone,
    b.title AS book_title,
    l.due_date,
    CURRENT_DATE - l.due_date AS overdue_days
FROM lend_record l
JOIN reader    r ON l.reader_id = r.reader_id
JOIN book_copy c ON l.copy_id   = c.copy_id
JOIN book      b ON c.book_id   = b.book_id
WHERE l.return_date IS NULL
  AND l.due_date < CURRENT_DATE;

-- 4.4 图书评价统计
CREATE VIEW v_book_reviews AS
SELECT
    b.book_id,
    b.title,
    COUNT(r.review_id) AS review_count,
    ROUND(AVG(r.score), 1) AS avg_score
FROM book b
LEFT JOIN review r ON b.book_id = r.book_id
GROUP BY b.book_id, b.title;

-- ---------------------------------------------------------------------
-- 5. 存储过程（4个）
-- ---------------------------------------------------------------------

-- 5.1 办理借书
CREATE OR REPLACE PROCEDURE sp_borrow_book(p_reader_id INT, p_copy_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_reader_status VARCHAR(10);
    v_copy_status   VARCHAR(10);
BEGIN
    SELECT status INTO v_reader_status
    FROM reader WHERE reader_id = p_reader_id;

    IF v_reader_status IS NULL THEN
        RAISE EXCEPTION '读者编号 % 不存在。', p_reader_id;
    END IF;
    IF v_reader_status != '正常' THEN
        RAISE EXCEPTION '读者账户状态异常（%），无法借阅。', v_reader_status;
    END IF;

    SELECT status INTO v_copy_status
    FROM book_copy WHERE copy_id = p_copy_id;

    IF v_copy_status IS NULL THEN
        RAISE EXCEPTION '单册编号 % 不存在。', p_copy_id;
    END IF;
    IF v_copy_status != '在馆' THEN
        RAISE EXCEPTION '该单册当前状态为（%），不可借阅。', v_copy_status;
    END IF;

    -- 插入借阅记录（借期30天），借阅量上限由触发器 trg_check_borrow_limit 校验
    INSERT INTO lend_record (reader_id, copy_id, borrow_date, due_date)
    VALUES (p_reader_id, p_copy_id, CURRENT_DATE, CURRENT_DATE + 30);

    -- 更改单册状态
    UPDATE book_copy SET status = '已借出' WHERE copy_id = p_copy_id;

    COMMIT;
END;
$$;

-- 5.2 办理还书
CREATE OR REPLACE PROCEDURE sp_return_book(p_lend_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_copy_id INT;
BEGIN
    SELECT copy_id INTO v_copy_id
    FROM lend_record WHERE lend_id = p_lend_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION '未找到对应的借阅记录。';
    END IF;

    -- 更新实际归还时间（若超期，触发器 trg_auto_penalty 自动生成罚单）
    UPDATE lend_record
    SET return_date = CURRENT_DATE
    WHERE lend_id = p_lend_id;

    -- 恢复单册状态
    UPDATE book_copy SET status = '在馆' WHERE copy_id = v_copy_id;

    COMMIT;
END;
$$;

-- 5.3 违约金清缴并解冻
CREATE OR REPLACE PROCEDURE sp_pay_penalty(p_penalty_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_reader_id      INT;
    v_unpaid_count   INT;
BEGIN
    UPDATE penalty
    SET status = '已缴清',
        pay_time = CURRENT_TIMESTAMP
    WHERE penalty_id = p_penalty_id
    RETURNING reader_id INTO v_reader_id;

    IF v_reader_id IS NULL THEN
        RAISE EXCEPTION '未找到对应的罚单。';
    END IF;

    SELECT COUNT(*) INTO v_unpaid_count
    FROM penalty
    WHERE reader_id = v_reader_id
      AND status = '未缴清';

    -- 全部缴清则解冻
    IF v_unpaid_count = 0 THEN
        UPDATE reader SET status = '正常' WHERE reader_id = v_reader_id;
    END IF;

    COMMIT;
END;
$$;

-- 5.4 批量添加馆藏单册
CREATE OR REPLACE PROCEDURE sp_add_book_copies(
    p_book_id  INT,
    p_count    INT,
    p_location VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    i INT := 1;
BEGIN
    WHILE i <= p_count LOOP
        INSERT INTO book_copy (book_id, location, status)
        VALUES (p_book_id, p_location, '在馆');
        i := i + 1;
    END LOOP;

    COMMIT;
END;
$$;

-- ---------------------------------------------------------------------
-- 6. 触发器（4个）
-- ---------------------------------------------------------------------

-- 6.1 还书超期自动生成罚单 (0.5元/天)
CREATE OR REPLACE FUNCTION trg_func_auto_penalty()
RETURNS TRIGGER AS $$
DECLARE
    v_days INT;
BEGIN
    IF NEW.return_date IS NOT NULL
       AND NEW.return_date > NEW.due_date THEN
        v_days := NEW.return_date - NEW.due_date;
        INSERT INTO penalty (lend_id, reader_id, amount)
        VALUES (NEW.lend_id, NEW.reader_id, v_days * 0.5);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auto_penalty
AFTER UPDATE ON lend_record
FOR EACH ROW
EXECUTE FUNCTION trg_func_auto_penalty();

-- 6.2 未缴清罚单自动冻结读者
CREATE OR REPLACE FUNCTION trg_func_freeze_reader()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = '未缴清' THEN
        UPDATE reader SET status = '冻结' WHERE reader_id = NEW.reader_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_freeze_reader
AFTER INSERT ON penalty
FOR EACH ROW
EXECUTE FUNCTION trg_func_freeze_reader();

-- 6.3 限制读者最多在借5本
CREATE OR REPLACE FUNCTION trg_func_check_borrow_limit()
RETURNS TRIGGER AS $$
DECLARE
    v_active_borrows INT;
BEGIN
    SELECT COUNT(*) INTO v_active_borrows
    FROM lend_record
    WHERE reader_id = NEW.reader_id
      AND return_date IS NULL;

    IF v_active_borrows >= 5 THEN
        RAISE EXCEPTION '该读者在借图书已达5本上限，请先归还！';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_borrow_limit
BEFORE INSERT ON lend_record
FOR EACH ROW
EXECUTE FUNCTION trg_func_check_borrow_limit();

-- 6.4 评价权限校验：必须借阅过该书目
CREATE OR REPLACE FUNCTION trg_func_check_review_auth()
RETURNS TRIGGER AS $$
DECLARE
    v_has_borrowed INT;
BEGIN
    SELECT COUNT(*) INTO v_has_borrowed
    FROM lend_record l
    JOIN book_copy c ON l.copy_id = c.copy_id
    WHERE l.reader_id = NEW.reader_id
      AND c.book_id   = NEW.book_id;

    IF v_has_borrowed = 0 THEN
        RAISE EXCEPTION '操作拒绝：您未曾借阅过该图书，无法发表评价。';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_review_auth
BEFORE INSERT ON review
FOR EACH ROW
EXECUTE FUNCTION trg_func_check_review_auth();

-- =====================================================================
-- 初始化完成
-- =====================================================================
