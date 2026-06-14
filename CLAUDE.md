# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

图书管理系统 (Library Management System) — 学生数据库实践课程期末项目(4人团队)。重点是数据库设计与操作实践，前后端保持简单。

## Tech Stack

- **Database**: PostgreSQL (存储过程/触发器/视图是课程核心考察点)
- **Backend**: Python FastAPI + uvicorn (尽量薄，业务逻辑交给DB层存储过程)
- **Frontend**: Vue 3 + Vite + TypeScript + Element Plus (组里无专门前端，保持简单)
- **管理**: uv (Python), pnpm (前端)

## Directory Structure

```
code/                         # git repo 根目录
├── docs/                     # 三份课程设计报告(.md)
├── sql/                      # 建表SQL + 种子数据
│   ├── init.sql              # 完整建表DDL
│   └── seed.sql              # 测试用种子数据
├── backend/                  # FastAPI 后端
│   ├── .venv/                # uv 虚拟环境(不入库)
│   └── .env                  # 环境变量(不入库)
├── frontend/                 # Vue 前端
└── CLAUDE.md
```

## Build & Run

> DB 参数放在 `backend/.env`（由 `.env.example` 拷贝），不入库。初始化前先填好连接信息。

```bash
# 数据库初始化（在 backend/.env 填好 PG 连接后）
psql -h <host> -p <port> -U <user> -d <db> -f sql/init.sql
psql -h <host> -p <port> -U <user> -d <db> -f sql/seed.sql

# 后端 (uv)
cd backend
cp .env.example .env       # 填写 PG_HOST/PG_PORT/PG_USER/PG_PASSWORD/PG_DB
uv sync
uv run uvicorn main:app --reload

# 前端
cd frontend
pnpm install
pnpm dev
```

## Architecture

### 核心设计: book(SPU) + book_copy(SKU) 分离

`book` 存抽象书目元数据，`book_copy` 存实体单册。借阅记录关联到 copy_id 而非 book_id。预约/评价针对 book_id(书目级别)。

### 9张表

| 表 | 用途 |
|---|---|
| `book` | 书目(SPU) |
| `book_copy` | 实体单册(SKU) |
| `category` | 分类字典 |
| `book_category` | 书目-分类 M:N 中间表 |
| `reader` | 读者信息 |
| `lend_record` | 借阅记录 |
| `penalty` | 逾期罚单(强依赖 lend_record) |
| `reservation` | 预约排队(针对书目) |
| `review` | 图书评价 |

### 状态约束 (CHECK)

- `reader.status`: 正常/冻结/注销
- `book_copy.status`: 在馆/已借出/遗失/破损
- `penalty.status`: 未缴清/已缴清
- `reservation.status`: 排队中/已通知/已取消/已完成
- `review.score`: 1~5

### 业务规则内置于DB层

- **存储过程** `sp_borrow_book`, `sp_return_book`, `sp_pay_penalty`, `sp_add_book_copies` — 后端直接 CALL，不重复实现业务逻辑
- **触发器**: 逾期自动生成罚单(0.5元/天)、罚单冻结读者、最大借阅量5本、评价需有借阅记录
- **视图**: `v_book_inventory`(库存), `v_reader_borrowing`(在借明细), `v_overdue_alert`(逾期预警), `v_book_reviews`(评价统计)

### 后端原则

- 调用存储过程而非在Python里写业务逻辑，后端只做路由转发+参数校验+错误处理
- 不用ORM，直接 psycopg2/asyncpg 执行 SQL
- JWT认证区分 admin/reader 两角色

### 前端原则

- 按功能页面拆: 书目列表、读者管理、借还操作台、统计看板
- 前端只做表单提交+数据展示，不做业务判断

## Design Docs

`docs/` 下三份md文件是课程设计报告，包含完整建表SQL、视图/存储过程/触发器SQL、数据字典、业务流程。开发时以此为准。

## Conventions

- 中文状态值(在馆/已借出 等)，不使用英文枚举
- PostgreSQL，SERIAL 主键，外键带 ON DELETE CASCADE
- 借期固定30天，逾期0.5元/天
