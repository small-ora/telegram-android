# GitHub 发布记录（2026-11-11）

> 目的：把代码与文档上传 GitHub，并让 **GitHub Actions 自动构建、发布 APK**；
> 本机此后只保留代码，不再承担构建运行环境。
> 结论：**仓库已创建、分支已推送、CI 已成功构建并发布 v13.1.1 Release**，APK 校验和与签名均已验证。

## 1. 仓库信息

| 项 | 值 |
|---|---|
| 仓库 | <https://github.com/small-ora/telegram-android>（**public fork** of [DrKLO/Telegram](https://github.com/DrKLO/Telegram)） |
| 默认分支 | `feat/no-sms-login-no-ads`（含扫码登录 + 去广告 + 文档；设为默认便于打开仓库即看到说明） |
| 上游分支 | `master`（官方镜像，保持不动，便于对比/升级） |
| 工作分支 | `feat/no-sms-login-no-ads`（日常开发与发布分支） |
| 远端配置 | `origin` = 本 fork；`upstream` = `https://github.com/DrKLO/Telegram.git` |
| 认证方式 | GitHub CLI 设备码（OAuth，未使用账号密码）；token 存于本机 `/root/.config/gh/hosts.yml`，可在 GitHub 设置中撤销 |

## 2. Release v13.1.1（首个自动构建产物）

| 项 | 值 |
|---|---|
| Tag | `v13.1.1`（指向 `f4b99503d`，即 CI workflow 修正后的提交） |
| Release 页 | <https://github.com/small-ora/telegram-android/releases/tag/v13.1.1> |
| APK | `tg-client-13.1.1-7237-arm64-release.apk`（40,662,542 字节） |
| SHA-256 文件 | `tg-client-13.1.1-7237-arm64-release.apk.sha256` |
| 构建任务 | [Actions run #42996586876](https://github.com/small-ora/telegram-android/actions/runs/42996586876) |
| 构建耗时 | 约 33 分钟（2026-11-11 17:36 → 18:09，冷构建） |
| 结果 | ✅ 全部 14 个步骤 success（构建 / 校验 / artifact / 创建 Release） |

### 2.1 APK 验证（本地下载后实测）

```text
$ sha256sum -c tg-client-13.1.1-7237-arm64-release.apk.sha256
tg-client-13.1.1-7237-arm64-release.apk: OK

$ apksigner verify --print-certs tg-client-13.1.1-7237-arm64-release.apk
Signer #1 certificate DN: CN=Android Developer, OU=Telegram, O=Telegram, ...
Signer #1 certificate SHA-256 digest: a08d7dc323ddf71ef3201944397e0d3cce7d40847263e11f328b68bbe19229ab
```

- 签名证书 SHA-256 = `a08d7dc3…`，与本地历史 release（S6b）**完全一致** → 可直接覆盖升级，不需要卸载重装；
- 版本：`13.1.1 (7237)`，包名 `org.telegram.messenger`，ABI 仅 `arm64-v8a`；
- 首次从官方 Telegram 切换过来仍需卸载官方版（包名相同、签名不同）。

## 3. CI 工作流

文件：`.github/workflows/build-apk.yml`

| 触发 | 行为 |
|---|---|
| push tag `v*` | 构建 release APK → 上传 artifact → **创建 GitHub Release** 并附加 APK + sha256 |
| `workflow_dispatch`（手动） | 仅构建，产物在该次 run 的 Artifacts 中（不建 Release） |

构建环境（与本地一致）：`ubuntu-22.04` + JDK 17（temurin）+ Android SDK 36 / build-tools 36.0.0 /
NDK 27.2.12479018 / CMake 3.22.1；`assembleRelease` 仅 `arm64-v8a`；签名使用仓库自带
`TMessagesProj/config/release.keystore`（上游公开测试签名）。首次构建约 33 分钟，Gradle 缓存后预计更快。

## 4. 后续更新流程（以后你只需要去 Release 下载）

```bash
# 1) 同步官方新版本（保留扫码登录 + 去广告）
git fetch upstream
./scripts/sync-upstream.sh            # 冲突处理见 docs/UPSTREAM-SYNC.md
./scripts/build-debug.sh              # 可选：本地验证；不做则直接靠 CI

# 2) 推送分支 + 打新版本标签（自动触发 CI 构建并发 Release）
git push origin feat/no-sms-login-no-ads
git tag v13.2.1
git push origin v13.2.1
```

CI 完成后在 <https://github.com/small-ora/telegram-android/releases> 下载最新 APK，
**同签名可直接覆盖安装**。

## 5. 本机职责调整

按用户要求「本机只保留代码、不在本地跑构建环境」：

- 源码、Git 历史、脚本、文档保留在 `/root/tg-client-docs`；
- 构建与发版统一交给 GitHub Actions（见 §3）；
- 本地 `build/` 等构建产物可在验证完成后清理（不进入版本库）；
- 本地保留 `artifacts/` 中的历史 APK 作为装机备份（不入库）。

## 6. 安全与合规

- 未使用/未保存 GitHub 账号密码；OAuth token 可随时撤销；
- `.session`、`.venv`、APK 产物均未入库（`.gitignore` 已覆盖）；
- 仓库为 GPLv2 源码 fork，README 已注明「非官方客户端」与商标/许可提示；
- Release 仅发布编译产物与校验和，不含任何密钥或账号信息。
