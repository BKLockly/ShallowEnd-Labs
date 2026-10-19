# ShallowEnd-Labs

ShallowEnd 测试环境集合，按 **CVE（真实漏洞）** 组织，每个靶场对应一个可复现漏洞的
Node.js 环境，用于验证注入与连接。靶场优先使用**真实开源项目 + 钉住的漏洞版本**
（`kind: upstream`），真实目标不可得时使用自写载体（`kind: carrier`，README 标注理由）。

> ⚠️ **免责声明**：本仓库所有环境均为**故意保留漏洞**的本地测试靶场，仅限在
> 本地授权环境下进行安全研究与测试，严禁用于任何未授权目标。

## 目录结构

| 目录 | 说明 |
|------|------|
| `base/` | 靶场环境（按 CVE-ID 命名，一目录一 CVE） |
| `injectors/` | 按 CVE 命名的内存马注入器（靶场唯一注入真源） |
| `shlabs.sh` | 统一生命周期管理脚本（自动发现 `base/*/shlabs.yml`） |
| `TESTING.md` | **测试指引**：逐环境讲解靶场信息与注入方法（后续测试从这里开始） |
| `AGENTS.md` | 仓库约定（新增/修改环境必读） |
| `THIRD_PARTY.md` | 上游项目归属（repo / ref / license / 实验室改动） |

## 环境清单

| 环境 | CVE | 漏洞 | 目标 | 端口 |
|------|-----|------|------|------|
| `base/CVE-2025-55182` | CVE-2025-55182 | React 19 RSC Flight 反序列化 RCE（CVSS 10.0） | RealWorld Conduit（cjfff/realworld-nextjs16 + gothinkster API） | 21501（API 21511） |
| `base/CVE-2026-73649` | CVE-2026-73649 | velocityjs ≤2.1.6 SSTI → RCE（CVSS 9.8） | VeloForge（carrier） | 21503 |
| `base/CVE-2026-45618` | CVE-2026-45618 | liquidjs <10.26.0 SSTI → RCE（CVSS 10.0，无补丁） | dungeon-revealer | 21504 |

## 生命周期

```
clean(清理) → up(启动) → inject(注入) → down(关闭)
```

| 命令 | 说明 |
|------|------|
| `./shlabs.sh list` | 列出所有可用环境（自动发现） |
| `./shlabs.sh clean <env>` | 清理：停止并删除容器/网络/卷/镜像 |
| `./shlabs.sh up <env>` | 启动：构建镜像 + 启动容器 |
| `./shlabs.sh inject <env> [--key <k>] [--verify] [--loader <f>]` | 注入 payload（前置漏洞版本校验门） |
| `./shlabs.sh test <env> [--verify]` | 全生命周期自测：clean → up → 健康检查 → inject → down |
| `./shlabs.sh down <env>` | 关闭：停止并删除容器 |
| `./shlabs.sh reset <env>` | 重置：clean + up |
| `./shlabs.sh logs <env>` | 查看日志 |
| `./shlabs.sh info <env>` | 查看环境信息 |

所有环境默认密钥 `mysecretkey`（`next-action` 头 = SHA1(key)，RC4 = MD5(key)[:16]）。

## 快速开始

```bash
# 启动 velocityjs 靶场
./shlabs.sh up CVE-2026-73649

# 注入内存马并验证协议握手（--verify 走 next-action 握手回环）
./shlabs.sh inject CVE-2026-73649 --key mysecretkey --verify

# 清理
./shlabs.sh clean CVE-2026-73649
```

逐环境的目标拓扑、触发端点、预期输出与常见问题见 **[TESTING.md](./TESTING.md)**。

## 许可

本仓库代码 MIT（[LICENSE](./LICENSE)）；构建期引入的上游项目归属见
[THIRD_PARTY.md](./THIRD_PARTY.md)。
