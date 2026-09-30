# Shallowend-Labs Agent 指南

本文档为 Agent（Claude Code / ZCode 等）在 `Shallowend-Labs` 仓库中创建和修改环境时
提供约束和指引。

## 组织原则：按 CVE 组织

`base/` 下每个靶场目录**对应一个真实漏洞（CVE）**，目录名即 CVE-ID（`base/<CVE-ID>/`）：

- 一个靶场的验收标准 = **能触发漏洞 + 能注入 emit 内存马 + 能通过 ShallowEnd 连接**。
- 只有出现新的真实漏洞（CVE）时，才考虑新增靶场。

## 靶场两类：upstream 优先

| 类型 | 含义 | 要求 |
|------|------|------|
| `kind: upstream` | **真实开源项目**作为目标（默认选择） | 构建时 `git clone` 钉 commit（ref 记录在 `shlabs.yml` 与 `THIRD_PARTY.md`），不 vendor 进仓；对上游的改动只允许漏洞版本钉位与 `patches/` 内声明的实验室补丁 |
| `kind: carrier` | 自写载体（真实目标不可得时的 fallback） | README 与 shlabs.yml 必须标注 `carrier` 并说明选型理由（现例：`base/CVE-2026-73649` —— velocityjs 生态无渲染用户可控模板的真实项目） |

选型前必须**验证利用前提**：依赖在漏洞区间 ≠ 可利用。示例负结果：carole-admin 锁
velocityjs 2.0.6，但全部 `Velocity.render()` 调用的模板均来自磁盘固定文件、无任何
用户输入拼接进模板文本，不满足"渲染攻击者可控模板"前提，不能作为 CVE-2026-73649 靶场。

### 漏洞版本钉位（核心约束）

真实项目依赖常为 `^range`，直接安装会解析到已修补版本。要求：

1. `package.json` 精确钉版 + lock 重建（npm/pnpm `overrides` 覆盖间接解析），或
   上游 lock 恰好落在漏洞区间（在 `shlabs.yml` target 注明）。
2. 每个环境 `inject.sh` 内置**漏洞版本校验门**：`docker compose exec` 读取容器内
   依赖版本（`node -e "require('./node_modules/<pkg>/package.json').version"`，注意
   部分 包 exports 不暴露 `./package.json`，必须走相对路径），不在漏洞区间即报错
   退出。
3. 上游漂移/上游结构变化的处理：`patches/` 内补丁 + `shlabs.yml` ref 同步更新。
4. **严禁升级钉版依赖**：钉在漏洞区间的版本是靶场的核心资产。任何人工或自动化手段
   （dependabot / renovate / `npm update` / `npm audit fix` / lock 重建）都不得把钉版
   依赖升级到已修补版本——升级即靶场静默失效。本仓库**不启用** dependabot / renovate；
   确需调整钉版（如换钉另一条漏洞线）时，必须在 commit 说明中论证新版本仍处于受影响
   窗口，并同步 `shlabs.yml`、`README.md` 与校验门断言。

### 端口分配

所有环境使用**高位端口**（21000-21999），按已占用靶场递增，不为未实现框架预留：

| 环境 | 端口 | 状态 |
|------|------|------|
| CVE-2025-55182 | 21501（front；RealWorld API 21511） | ✅ 已占用 |
| CVE-2026-73649 | 21503 | ✅ 已占用 |
| CVE-2026-45618 | 21504 | ✅ 已占用 |
| CVE-2022-29078（EJS） | ~~21502~~ 已释放（无真实目标，环境已删除） | — |

> 新增靶场按顺序取下一个可用端口（21505 起；多服务环境的辅助服务继续递增，
> 如 21511）。仅绑定 `127.0.0.1`。

## 每环境目录结构

```
base/<CVE-ID>/
├── Dockerfile(.front/.api)  # 多阶段构建；upstream 用 ARG UPSTREAM_REPO/UPSTREAM_REF clone 钉版
├── docker-compose.yml       # 服务编排（127.0.0.1 绑定高位端口；多服务用 depends_on: service_healthy）
├── shlabs.yml               # 环境元信息（name/cve/port 为顶层标量，供 shlabs.sh 解析）
├── README.md                # 免责声明头 + CVE/目标/钉版/触发端点/注入/连接参数
├── inject.sh                # 注入入口（版本校验门 → 调 injectors/<injector>.py）
├── patches/                 # 对上游的钉位/实验室补丁（每处改动可追溯）
└── .env.example             # 构建代理等本地变量样例（.env 已 gitignore）
```

### shlabs.yml schema

```yaml
name: <别名>                # 可选；shlabs.sh 可用目录名或 name 定位环境
cve: CVE-XXXX-YYYY
vuln: <一行漏洞描述>
port: 215xx
target:
  kind: upstream | carrier
  repo: <上游仓库 URL>       # upstream
  ref: <钉定 commit>         # upstream
  license: <SPDX>           # upstream
inject:
  injector: <injectors/ 下的文件名>
  endpoint: <触发端点>
healthcheck:
  path: /
```

### Dockerfile 规范

- 多阶段构建（build → runtime）；基础镜像 alpine 优先，按依赖实际需要选择
  （Prisma 4 必须 Debian 系；node:16 系列需切 archive.debian.org 源，bullseye 已归档）
- runtime 设置 `NODE_ENV=production`、`PORT=<高位端口>`，只复制运行所需文件
- 构建期网络：可选 `HTTPS_PROXY`/`HTTP_PROXY` build args（`.env` 的
  `SHLABS_BUILD_PROXY` 注入），不写死代理地址

## 注入器约定（injectors/）

- 每个 CVE 一个独立脚本：`cve-<id>_<载体>.py`，随本仓开源
- 统一接口：`--target --key [--loader] [--verify] [--payload]`（+ 各自特有选项）
  - `--loader`：读取生成器产出的 emit 壳文件作为注入载荷，并校验壳内 RC4 key /
    next-action 与 `--key` 派生值一致
  - `--verify`：注入后发 next-action 探测请求（HTTP POST，RC4 加密的 trivial
    payload），确认 emit override 已接管
- 线协议常量：`Next-Action = SHA1(key)`、`RC4 key = MD5(key)[:16]`（与 ShallowEnd
  客户端共享，非安全控制，不可更换算法）
- 非 HTTP 传输的靶场（如 socket.io GraphQL）在注入器 docstring 里写明协议细节

## 新增环境流程

1. 确定 CVE 与利用前提（模板/输入是否攻击者可控），选 upstream 目标（或说明理由用 carrier）
2. 取下一个可用端口；创建 `base/<CVE-ID>/`
3. Dockerfile（clone 钉 commit）+ 漏洞版本钉位 patch + docker-compose.yml
4. shlabs.yml / README.md（免责声明头）/ inject.sh（版本校验门）
5. 本地 `docker compose up -d --build` 验证构建运行，触发漏洞端点验证复现
6. 注入脚本验证 emit 内存马注入 + 连接
7. 更新顶层 `README.md` 环境清单、`TESTING.md`、`THIRD_PARTY.md`（upstream 时）
8. 提交并推送

## ShallowEnd MCP 服务对接

ShallowEnd 主项目内置 MCP 服务（SSE，默认 `127.0.0.1:8080`）。靶场连接常用：

```json
{
  "method": "tools/call",
  "params": {
    "name": "webshell_create",
    "arguments": {
      "group_id": 1,
      "profile_id": 1,
      "name": "shlabs-<env>",
      "url": "http://127.0.0.1:215xx",
      "shell_type": "emit",
      "mark": "靶场"
    }
  }
}
```

- `group_id` / `profile_id` 换成本地库中的实际 ID（示例占位为 1）
- `shell_type` 固定 `emit`（框架无关的 emit 内存马，仅作标识；连接与类型无关）
- 注入器 `--loader` 参数可直接接 ShallowEnd 生成页导出的 emit 壳文件
