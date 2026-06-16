# 📚 图书管理系统

> 数据库实践课程期末项目 | 4人团队  
> **技术栈**：PostgreSQL + Python FastAPI + Vue 3 + Element Plus

## 功能概览

- 书目检索与管理（SPU/SKU 分离设计）
- 借阅 / 归还 / 续借 / 预约
- 逾期自动生成罚单、读者冻结与解冻
- 读者评价与预约排队
- 统计看板（库存、在借、逾期预警、评价统计）

## 目录结构

```
code/
├── sql/
│   ├── init.sql        # 完整建表 DDL（9 张表 + 索引 + 角色 + 4 视图 + 4 存储过程 + 4 触发器）
│   └── seed.sql        # 测试种子数据
├── backend/            # FastAPI 后端（Python）
│   ├── db.py           # 连接池 + 查询工具
│   ├── auth.py         # JWT 认证（admin/reader）
│   ├── schemas.py      # Pydantic 模型
│   ├── main.py         # 应用入口
│   └── routers/        # 路由模块
├── frontend/           # Vue 3 前端
│   └── src/
│       ├── views/      # 页面（书目 / 读者 / 借还 / 统计 / 登录）
│       ├── router/     # 路由配置
│       ├── store/      # 状态管理
│       └── api.ts      # Axios 封装
└── docs/               # 课程设计报告
```

## 快速启动

### 1. 数据库初始化

```bash
# 创建数据库后执行
psql -h <host> -p <port> -U <user> -d <db> -f sql/init.sql
psql -h <host> -p <port> -U <user> -d <db> -f sql/seed.sql
```

### 2. 后端

```bash
cd backend
cp .env.example .env   # 填写数据库连接信息
uv sync                # 安装依赖
uv run uvicorn main:app --reload   # http://localhost:8000
```

### 3. 前端

```bash
cd frontend
pnpm install
pnpm dev               # http://localhost:5173
```

### 4. 登录

- **管理员**：账号 `admin`，密码 `admin123`
- **读者**：证号 `R2026001`（张三）

## 数据库设计

### 9 张表

| 表 | 说明 |
|----|------|
| `book` | 书目（SPU） |
| `book_copy` | 实体单册（SKU） |
| `category` | 分类字典 |
| `book_category` | 书目-分类 M:N |
| `reader` | 读者信息 |
| `lend_record` | 借阅记录 |
| `penalty` | 逾期罚单 |
| `reservation` | 预约排队 |
| `review` | 图书评价 |

### 核心业务规则（DB 层实现）

| 类型 | 名称 | 功能 |
|------|------|------|
| 存储过程 | `sp_borrow_book` | 办理借书（校验读者/单册状态） |
| 存储过程 | `sp_return_book` | 办理还书 |
| 存储过程 | `sp_pay_penalty` | 缴清罚单并解冻读者 |
| 存储过程 | `sp_add_book_copies` | 批量添加馆藏单册 |
| 视图 | `v_book_inventory` | 图书库存统计 |
| 视图 | `v_reader_borrowing` | 读者当前在借 |
| 视图 | `v_overdue_alert` | 超期违约预警 |
| 视图 | `v_book_reviews` | 评价统计 |
| 触发器 | `trg_auto_penalty` | 还书超期自动生成罚单 |
| 触发器 | `trg_freeze_reader` | 未缴罚单自动冻结读者 |
| 触发器 | `trg_check_borrow_limit` | 限制最多在借 5 本 |
| 触发器 | `trg_check_review_auth` | 评价须有借阅记录 |

## API 接口

| 模块 | 接口 |
|------|------|
| 认证 | `POST /api/login/admin`、`/api/login/reader` |
| 书目 | `GET /api/books`、`GET /api/books/{id}`、`POST /api/books`、`POST /api/books/{id}/copies` |
| 分类 | `GET /api/categories` |
| 评价 | `POST /api/reviews` |
| 读者 | `GET /api/readers`、`GET /api/readers/me`、`POST /api/readers` |
| 借还 | `POST /api/lend/borrow`、`POST /api/lend/return` |
| 罚单 | `POST /api/penalty/{id}/pay`、`GET /api/penalties` |
| 预约 | `POST /api/reservations`、`GET /api/reservations` |
| 统计 | `GET /api/stats/{inventory\|overdue\|borrowing\|reviews}` |
| 健康 | `GET /api/health` |

## 约束

- 借期固定 30 天，逾期 0.5 元/天
- 读者状态：正常 / 冻结 / 注销
- 单册状态：在馆 / 已借出 / 遗失 / 破损
- PostgreSQL，SERIAL 主键，外键 ON DELETE CASCADE
