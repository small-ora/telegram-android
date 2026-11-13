# 自用 Telegram Android 客户端（官方源码 fork）

基于官方 Android 客户端源码 [DrKLO/Telegram](https://github.com/DrKLO/Telegram)（GPLv2）维护的个人自用分支，
在保留官方功能的前提下做了两处改动：

1. **扫码登录**：新设备登录页提供「扫描二维码登录」，用已登录的旧手机确认即可完成登录（含 DC 迁移与 2FA），不需要接收短信验证码；
2. **去除广告**：关闭频道 / Bot 内的赞助消息、会话搜索中的推荐频道、视频/图片查看器的贴片广告。

> ⚠️ **非官方客户端**。本项目与 Telegram 官方无关；所有源码版权归原作者（见 [LICENSE](LICENSE)）。
> 仅用于个人自用与学习；公开分发 APK 前请自行评估许可（GPLv2）、商标与 Telegram API 条款风险。

## 当前状态

- 上游基线：`DrKLO/Telegram` 13.2.2（commit `21f7d109`，2026-11-12，已同步；上一版基线 13.2.1 `7be672e`），升级方式见 [docs/UPSTREAM-SYNC.md](docs/UPSTREAM-SYNC.md)；
- 改动分支：`feat/no-sms-login-no-ads`（4 个代码 commit，均为小范围改动）；
- 构建：`assembleDebug` / `assembleRelease` 均已通过（JDK 17 + SDK 36 + NDK 27.2）；证据见 [docs/evidence/](docs/evidence/)；
- 真机：扫码登录（含 2FA）、去广告已验证通过，记录见 [docs/evidence/S7-realtime-validation.md](docs/evidence/S7-realtime-validation.md)。

## 本分支的改动

| 提交 | 内容 | 涉及文件 |
|---|---|---|
| `ca4085c` | 去广告（频道/Bot 赞助消息 + 搜索推荐频道） | `BuildVars`、`MessagesController`、`ChatActivity`、`DialogsSearchAdapter` |
| `bc9e3c6` | 去广告（视频/图片查看器贴片） | `video/VideoAds.java` |
| `de96d77` | 扫码登录（二维码页、轮询、DC 迁移、2FA 衔接） | `LoginActivity`、`res/values/strings.xml` |
| `1437581` | 二维码页尺寸修复 + 扫码链路错误日志 | `LoginActivity` |

设计、代码定位与验证过程见 [docs/spec/](docs/spec/) 与 [docs/recon/](docs/recon/)；
GPL 要求的修改记录见 [docs/MODIFICATIONS.md](docs/MODIFICATIONS.md)。

## 仓库结构

```
<repo-root>/
├── docs/                      # 全部项目文档（见 docs/README.md 索引）
│   ├── spec/                  # 需求规格（v2.1 冻结版 + v2.2 提案）
│   ├── recon/                 # 环境勘察 / 源码勘察
│   ├── evidence/              # 编译与真机验证证据（含日志、截图）
│   ├── PLAN.md                # 开发计划与执行记录
│   ├── ACCEPTANCE.md          # 验收包
│   ├── BUILD.md               # 构建指南
│   ├── UPSTREAM-SYNC.md       # 升级同步官方版本的流程
│   └── MODIFICATIONS.md       # 修改记录（GPL 要求）
├── patches/                   # 本分支的补丁序列（灾难恢复 / 手工重放用）
├── scripts/                   # 构建、同步、校验脚本
├── tools/probe/               # Telegram API 探针脚本（Python + Telethon）
├── TMessagesProj*/            # 官方源码（Fork 自 DrKLO/Telegram）
└── ...                        # 官方构建文件（gradlew、build.gradle 等）
```

`artifacts/`（本地 APK 产物）、`backup-*/`（本地备份）和任何会话文件都**不纳入版本库**，见 `.gitignore`。
上游原始 README 存档在 [docs/upstream-README.md](docs/upstream-README.md)。

## 构建（快速开始）

要求：JDK 17、Android SDK 36（build-tools 36.0.0）、NDK 27.2.12479018、CMake 3.22.1。
完整说明（含 release 签名与常见问题）见 [docs/BUILD.md](docs/BUILD.md)。

```bash
cd <repo-root>
git submodule update --init --recursive        # 首次克隆后
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ANDROID_HOME=/opt/android-sdk ANDROID_SDK_ROOT=/opt/android-sdk

# debug（包名带 .beta，可与官方版共存）
./scripts/build-debug.sh

# release（沿用仓库自带的 config/release.keystore 签名）
./scripts/build-release.sh
```

## 下载 / 更新（GitHub Releases）

编译产物不走本地环境，由 **GitHub Actions 自动构建并发布 Release**：

- 下载地址：<https://github.com/small-ora/telegram-android/releases>（当前最新 `v13.2.2`，安装 `tg-client-*-arm64-release.apk` 即可）；
- 触发方式：推送 `v*` 标签（如 `v13.2.2`）→ 自动构建 release APK + 创建 Release；
- 只构建不发布：Actions 页面手动 Run workflow，产物在 run 的 Artifacts 中；
- 与历史 Release 使用同一签名（仓库自带 `config/release.keystore`），可覆盖升级；
  与官方版包名冲突，首次安装需先卸载官方 Telegram（聊天数据在云端，不丢）。
- 安装包已确保不带 `android:testOnly`（CI 有强制校验）：v13.1.1 / v13.2.1 的旧 APK 在手机上点安装
  会失败（需 `adb install -t`），从 `v13.2.2` 起已修复，可直接下载安装。

## 升级同步官方版本

目标是「官方新版本 + 保留登录与去广告改动」。推荐流程（详见 [docs/UPSTREAM-SYNC.md](docs/UPSTREAM-SYNC.md)）：

```bash
git fetch upstream --tags
./scripts/sync-upstream.sh            # 把本分支 rebase 到最新上游
# 解决冲突（集中在 LoginActivity.java / strings.xml）→ 构建 → 真机冒烟 → push
```

若 `rebase` 冲突过多，可用 `patches/` 中的补丁序列手工重放（`git am patches/*.patch`）。

## 文档索引

- [docs/README.md](docs/README.md) — 文档总索引与阅读顺序
- [docs/BUILD.md](docs/BUILD.md) — 环境、构建、签名、排错
- [docs/UPSTREAM-SYNC.md](docs/UPSTREAM-SYNC.md) — 跟随官方升级
- [docs/MODIFICATIONS.md](docs/MODIFICATIONS.md) — 相对官方的全部修改（GPL 记录）
- [docs/PLAN.md](docs/PLAN.md)、[docs/ACCEPTANCE.md](docs/ACCEPTANCE.md) — 开发计划与验收记录
- [docs/spec/](docs/spec/)、[docs/recon/](docs/recon/)、[docs/evidence/](docs/evidence/) — 规格、勘察、证据

## 许可

源码遵循 **GNU GPL v2**（见 [LICENSE](LICENSE)），版权归 Telegram / 上游作者所有。
本仓库的修改同样以 GPLv2 发布；分发编译产物时须同时提供对应源码。
