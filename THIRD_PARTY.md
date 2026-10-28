# Third-Party Notices

本仓库的 `base/` 靶场在**构建时**从下列上游项目 clone 钉定 commit（不 vendor 进仓）。
上游代码版权归各自作者所有，本仓库对其的使用遵循上游许可证；对各上游所做的
改动仅限 `patches/` 与 `shlabs.yml` 中声明的漏洞版本钉位/实验室补丁。

| 上游项目 | 用途（靶场） | 钉定 ref | 许可证 | 实验室改动 |
|----------|-------------|----------|--------|-----------|
| [cjfff/realworld-nextjs16](https://github.com/cjfff/realworld-nextjs16) | `base/CVE-2025-55182` 前端 | `489753d6a47c28fabcad33d4c8098cb4f2ae52e2` | MIT | `patches/pin-vulnerable.cjs`：next/react 钉回 16.0.6/19.2.0（漏洞版本，含 pnpm overrides） |
| [gothinkster/node-express-realworld-example-app](https://github.com/gothinkster/node-express-realworld-example-app) | `base/CVE-2025-55182` RealWorld API | `30b68e1e881462b2f4164ea09ab4c4f5699c7b0b` | MIT | `patches/seed-sequential.patch`：seed 顺序化（规避 Prisma 4 引擎高并发 double-free） |
| [dungeon-revealer/dungeon-revealer](https://github.com/dungeon-revealer/dungeon-revealer) | `base/CVE-2026-45618` | `2fab4fdb19d3c3a8865f96c5172805325ab8bb7c` | ISC | `patches/pin-vulnerable.cjs`：liquidjs 钉到 10.25.7（官方 gadget 链依赖 10.x 内部结构；10.25.7 同在 CVE-2026-45618 受影响窗口且暴露 CVE-2026-44646） |
| [node-red/node-red](https://github.com/node-red/node-red) | `base/CVE-2026-77413` | Docker 镜像 tag `4.1.11`（2026-05-08 发布，早于 2026-07-13 披露；jsonata 精确 pin 2.0.6） | Apache-2.0 | **无**（默认配置即受影响形态：无 adminAuth，/flows 未认证可达） |

`base/CVE-2026-73649`（VeloForge）为 `kind: carrier` 自写载体（velocityjs 生态无
"渲染用户可控模板"的真实开源项目；唯一候选 carole-admin 经核实模板不可控、不满足
利用前提），不含第三方代码。

注入器（`injectors/`）与靶场管理脚本为本仓库原创，MIT。
