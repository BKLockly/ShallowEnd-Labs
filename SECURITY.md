# Security Policy

## 性质说明（Supported Scope）

本仓库是 ShallowEnd 平台的**本地授权测试靶场**集合：`base/` 下均为故意保留已知漏洞
（CVE）的 Node.js 应用环境，`injectors/` 为对应的内存马注入器。靶场中的漏洞是本仓库
的核心资产，**不属于需要报告的安全问题**。

## 报告漏洞（Reporting a Vulnerability）

如发现本仓库自身工具链的安全问题（例如：`shlabs.sh` / `inject.sh` 的脚本注入风险、
注入器对密钥材料的不当处理、构建脚本对上游 clone 内容的信任边界问题），请使用
GitHub 的**私密漏洞报告**（Private vulnerability reporting），不要开公开 issue。

## 负责任使用（Responsible Use）

本仓库所有内容**仅限在本地授权环境下进行安全研究与测试**。对未授权目标使用其中
任何工具（注入器 / 内存马）在大多数司法辖区属于违法行为，维护者对滥用不承担
任何责任。

## 靶场完整性（Lab Integrity）

漏洞依赖的钉版（`patches/pin-vulnerable.cjs` + lock）是靶场可用性的根基：

- 严禁任何人工或自动化依赖升级手段（dependabot / renovate / `npm update` /
  `npm audit fix` / lock 重建）将钉版依赖升级到已修补版本——升级即靶场静默失效；
- 发现钉版漂移或版本校验门被绕过，请按安全问题对待，走上面的私密漏洞报告渠道。
