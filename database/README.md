# database — 共享数据库靶标（按引擎组织）

脱离业务场景的独立数据库容器群，供注入后的 webshell 通过 docker 内网做 SQL 操作练习/演练。与 `base/` 靶场解耦：靶场容器加入 `shlabs-net` 网络后即可通过容器名直连。

## 目录

```
database/
├── docker-compose.yml        # mysql + postgres + sqlite 三服务，共享网络 shlabs-net
├── mysql/init/               # 01_schema.sql（结构） + 02_data.sql（生成种子）
├── postgresql/init/          # 同上（HR 域）
├── sqlite/init/schema.sql    # SQLite 建库脚本（notes 应用域）
└── scripts/gen_seeds.py      # 种子生成器（固定随机种子，可复现；改完重跑生成 02_data.sql）
```

## 连接信息（固化统一）

| 引擎 | 容器名 | 内网地址 | 库名 | 用户/密码 |
|------|--------|----------|------|-----------|
| MySQL 8.4 | `shlabs-mysql` | `shlabs-mysql:3306` | `shlabs_ecom`（电商域，13 表） | `shlabs` / `shlabs_pass`（root 密码 `shlabs_root_pass`） |
| PostgreSQL 16 | `shlabs-postgres` | `shlabs-postgres:5432` | `shlabs_hr`（HR 域，12 表） | `shlabs` / `shlabs_pass` |
| SQLite | `shlabs-sqlite` | 文件（无网络服务） | `/data/shlabs_notes.db`（notes 域，4 表） | — |

- **不对宿主机发布任何端口**——只在 `shlabs-net` 网络内部可达
- 数据落 named volume（`shlabs_mysql_data` / `shlabs_pg_data` / `shlabs_sqlite_data`），`down` 不丢数据，`down -v` 重置

## 使用

```bash
# 启动/停止（在 database/ 目录）
docker compose up -d
docker compose down          # 保数据
docker compose down -v       # 重置数据（重新执行 init 灌种子）

# 让某个靶场环境接入（二选一）
docker network connect shlabs-net <靶场容器名>     # 运行时单容器接入
# 或在靶场 compose 里声明外部网络：
#   networks: { shlabs-net: { external: true } }
```

接入后，webshell 数据库功能里按上表配置连接（host 填容器名）。

**SQLite 特例**：文件数据库无网络形态，webshell 读的是**webshell 宿主容器文件系统**里的 .db 文件，两种接入方式：

1. **共享卷**（推荐，持久）：靶场 compose 声明外部 volume `shlabs-db_shlabs_sqlite_data` 挂到容器内任意路径（如 `/data`），host 填 `<挂载路径>/shlabs_notes.db`（CVE-2026-73649 已接入）；
2. **一次性拷贝**（夹具式）：`docker cp` 把 .db 文件塞进靶场容器，容器重建即丢。

## 种子数据

- **MySQL `shlabs_ecom`（电商域）**：users(800) / merchants(60) / categories(18，两级) / products(640) / product_images(512) / addresses(388) / orders(500) / order_items(800) / payments(465) / reviews(720) / coupons(46) / user_coupons(333) / audit_logs(800)
- **PostgreSQL `shlabs_hr`（HR 域）**：departments(12) / employees(476) / salary_records(800) / attendance(800) / leave_requests(264) / performance_reviews(352) / projects(47) / project_members(189) / job_postings(26) / candidates(214) / interviews(158) / assets(318)
- **SQLite `shlabs_notes.db`（notes 域，手写种子）**：users(3，含 bcrypt 哈希) / sessions(2，含 JWT 形态 token) / posts(2) / app_config(7，预置 aws_access_key/aws_secret_key/smtp_password/stripe_key 等凭据形状值——同时是 `mem_search` 类内存凭据插件的扫描靶标)

每表行数 1~800 随机（固定随机种子 20260930，产物可复现）；外键按依赖顺序生成，时间跨度数月到数年。调整表结构/行数：改 `scripts/gen_seeds.py` 与对应 `01_schema.sql` 后重跑 `python3 scripts/gen_seeds.py`，再 `docker compose down -v && up -d` 重新灌数。

## 注意

- 靶场接入本网络后，目标机进程可直连数据库——这本身就是演练面：配合 ShallowEnd webshell 的数据库功能（配置 CRUD / 库表列浏览 / SQL / 导出 / 驱动插件），完整还原"从内存马到数据"的路径
- `mysql2/pg` npm 包由各靶场镜像自行决定是否预装；未装时走 ShallowEnd 驱动插件（`mysql_driver`/`pg_driver`）兜底
- `sqlite_driver` 插件（sql.js 纯 JS 构建）经 `dbDriverLoad` 内存加载后按文件路径打开 .db：整库内存态、`run` 后自动写回源文件（非事务安全，目标机进程并发写会互相覆盖）
