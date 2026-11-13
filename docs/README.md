# 文档索引

本目录收录自用 Telegram Android 客户端分支的全部文档：需求规格、勘察、计划、验证证据、验收与维护指南。
文档写作与验证过程遵循 `ai-dev-workflow`（SPEC → PLAN → 分步实现 → 证据 → 独立审查 → 人工验收）。

## 快速导航

| 想看什么 | 去哪 |
|---|---|
| 项目总览 / 构建 / 许可 | 仓库根 [README.md](../README.md) |
| 怎样编译、签名、排错 | [BUILD.md](BUILD.md) |
| 怎样跟随官方升级（保留改动） | [UPSTREAM-SYNC.md](UPSTREAM-SYNC.md) |
| 相对官方改了哪些代码（GPL） | [MODIFICATIONS.md](MODIFICATIONS.md) |
| 需求规格（冻结版） | [spec/SPEC-v2.1-frozen.md](spec/SPEC-v2.1-frozen.md) |
| v2.2 更正提案（待冻结） | [spec/SPEC-v2.2-proposal.md](spec/SPEC-v2.2-proposal.md) |
| 开发计划与执行记录 | [PLAN.md](PLAN.md) |
| 验收包 | [ACCEPTANCE.md](ACCEPTANCE.md) |
| 环境 / 源码勘察 | [recon/environment.md](recon/environment.md)、[recon/source.md](recon/source.md) |
| 编译与真机证据 | [evidence/](evidence/) |

## 目录结构

```
docs/
├── README.md                 # 本文件
├── BUILD.md                  # 构建 / 签名 / 排错
├── UPSTREAM-SYNC.md          # 升级同步官方版本的流程
├── MODIFICATIONS.md          # 相对官方的修改记录（GPL 要求）
├── PLAN.md                   # 开发计划 + 执行记录
├── ACCEPTANCE.md             # 验收包（v1，2026-11-02）
├── spec/
│   ├── SPEC-v1-history.md    # 初版（历史）
│   ├── SPEC-v2.1-frozen.md   # 冻结基线（sha256 5f03b94b…，commit ecd0b17）
│   └── SPEC-v2.2-proposal.md # 更正提案（待确认冻结）
├── recon/
│   ├── environment.md        # 构建环境与工具链勘察
│   └── source.md             # 登录链路 + 广告位源码勘察（行号级）
├── evidence/
│   ├── M0-spike-result.md    # 扫码通道可行性验证
│   ├── qr-token-poll-probe.md# 二维码轮询行为实测
│   ├── M1-build-result.md    # 基线编译通过
│   ├── S3-ads-removal.md     # 去广告实现与验证
│   ├── S4-qr-login.md        # 扫码登录实现与验证
│   ├── S6-release-build.md   # release 构建
│   ├── S7-realtime-validation.md # 真机验证记录
│   ├── REPO-RESTRUCTURE-20261111.md # 仓库合并与整理记录（2026-11-11）
│   ├── GITHUB-PUBLISH-20261111.md # GitHub 发布与 CI 构建记录（2026-11-11）
│   ├── UPGRADE-13.2.1-20261111.md # 同步官方 13.2.1 记录（2026-11-11）
│   ├── INSTALL-TESTONLY-FIX-20261113.md # 安装失败根因（testOnly）与修复、v13.2.2 发布验证（2026-11-13）
│   ├── artifacts-SHA256SUMS.txt # 本地 APK 产物的校验和存档
│   ├── logs/                 # 每次构建的完整日志
│   ├── screenshots/          # 真机截图
│   └── frozen/SPEC_BASE.txt  # SPEC 冻结记录（sha256 / 时间 / 依据）
└── upstream-README.md        # 上游 DrKLO/Telegram 原 README 存档
```

## 建议阅读顺序

1. 仓库根 `README.md`（是什么、怎么构建）；
2. `spec/SPEC-v2.1-frozen.md` + `spec/SPEC-v2.2-proposal.md`（要做什么、验收标准）；
3. `recon/source.md`（登录链路与广告位在哪）；
4. `PLAN.md`（怎么做、做到哪一步）；
5. `evidence/` + `ACCEPTANCE.md`（做了什么、验证到什么程度）；
6. `UPSTREAM-SYNC.md`（以后怎么跟着官方升级）。

## 文档约定

- 文件名与正文以中文为主；代码路径、命令、API 名保持原文。
- `<repo-root>` 表示仓库根目录（本地即当前工作区）。
- 证据类文档（`evidence/`）按时间顺序追加，不覆盖历史结论；结论变化在新文档中标注 `old → new`。
- `spec/` 中的冻结版本（`*-frozen.md`）不可修改；变更须出新版本并由人确认。
- 与代码实现不一致的历史文档保留在 `spec/SPEC-v1-history.md` 中作对照，不删除。
