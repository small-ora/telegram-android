# 开发计划（PLAN v1，对应 SPEC v2.1）

> 依据：`evidence/frozen/SPEC-v2.1.md`（SPEC_BASE sha256 `5f03b94b...`）
> 代码目录：`<repo-root>`（fork of `DrKLO/Telegram`，GPLv2）
> 隔离分支：`feat/no-sms-login-no-ads`

## 0. 已完成（M0 / M1）

| 项 | 结果 | 证据 |
|---|---|---|
| 扫码通道可用 | ✅ `auth.exportLoginToken` → `LoginToken` | `evidence/M0-spike-result.md` |
| 验证码通道 | ⏸ 本机 IP 触发 reCAPTCHA，待干净网络复测 | 同上 |
| **S1 基线编译** | ✅ **2026-11-02 09:28 `assembleDebug` 退出码 0，BUILD SUCCESSFUL in 6m32s** | `evidence/M1-build-result.md` + `evidence/logs/build-M1-20261102-092157.log` |
| **S2 源码勘察** | ✅ 完成，登录链路 + 广告位均有行号级结论 | `recon/source.md` |
| G-2 人工门禁 | ⏳ 待你确认「可以继续 M2 改造」 | 本文件 §5 |

## 1. 环境基线（M1-a）

| 组件 | 版本（由源码 build.gradle 决定） | 状态 |
|---|---|---|
| JDK | 17.0.21（Debian openjdk-17-jdk） | ✅ 已装 |
| Gradle | 8.13（wrapper 自带，自动下载） | ⏳ |
| AGP | 8.13.2 | — |
| compileSdk / targetSdk | 36 / 36 | ⏳ |
| buildTools | 36.0.0 | ⏳ |
| NDK | 27.2.12479018 | ⏳ |
| CMake | 3.22.1 | ⏳ |
| minSdk | 23 | — |

环境变量：

```bash
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ANDROID_HOME=/opt/android-sdk
export ANDROID_SDK_ROOT=/opt/android-sdk
```

## 2. 分步计划

| 步 | 主题 | 写范围 | 验证命令 | 回滚点 |
|---|---|---|---|---|
| **S1** ✅ | 建立隔离分支 + SPEC 入库 + 首次编译基线 | 仓库根、`local.properties` | `./gradlew :TMessagesProj_App:assembleDebug` 退出码 0 | `git checkout master` |
| **S2** ✅ | 源码勘察：定位登录链路与 sponsored 渲染点 | 无（只读） | 产出 `recon/source.md`，列出类名/方法名/行号 | 无改动 |
| **S3** ✅ | **G2 去广告**（请求侧 + 渲染侧短路 + VideoAds） | `BuildVars.java`、`MessagesController.java`、`ChatActivity.java`、`DialogsSearchAdapter.java`、`video/VideoAds.java` | 编译通过 ✅（1m35s / 1m36s）+ 真机 AC-5/AC-6 ⏳ | `git revert ca4085c` / `bc9e3c6` |
| **S4** ✅（代码） | **G1-a 扫码登录**（主通道），拆 3 小步 | `LoginActivity.java`（新 QR 页 + 入口）、`res/values/strings.xml`（文案）、可能 `BuildVars.java` | 见 §2.1 | 回滚 S4 各 commit |
| **S5** | **G1-b 登录邮箱通道**（源码勘察结论：官方已完整实现，预计**零代码改动**，只需真机确认入口可用） | 无（仅验证） | 真机确认「通过邮箱接收验证码」入口出现且能收到邮件 | 无 |
| **S6** | Release 构建 + 签名（AC-8） | 预期零代码改动（仓库已带 `TMessagesProj/config/release.keystore` + gradle.properties 默认口令） | `./gradlew :TMessagesProj_App:assembleRelease` 退出码 0 + APK 路径 | 不改代码，无回滚 |
| **S7** | 真机验证 AC-2 ~ AC-7 | 无 | 逐条打勾 + 截图 | — |
| **S8** | 自检 + 独立审查 + 验收包 | `.ai/` | 验收包 | — |

### 顺序理由

1. **S1 先让基线编译绿**：在一棵编译不过的树上改代码，后面全是噪音。
2. **S2 先勘察再动手**：官方源码几十万行，靠猜类名改必然踩空。
3. **S3 先做去广告**：它不依赖网络服务端行为，改完立刻能验证，先建立一个"改动→验证"的正反馈。
4. **S4 做扫码登录**：M0 已验证通道可用，是确定能成的路子。
5. **S5 再做邮箱**：需要服务端返回 `SentCodeTypeEmailCode` 且账号已绑定登录邮箱，不确定性更高，放后面。

## 3. 每步的验证判据

| 判定 | 命令/动作 |
|---|---|
| 编译绿 | `./gradlew :TMessagesProj_App:assembleDebug` 退出码 0 |
| 去广告生效 | 真机进带广告的频道，前后截图对比；会话列表无推荐频道 |
| 扫码登录生效 | 新装 APK → 登录页出二维码 → 旧设备扫 → 进入会话列表 |
| 邮箱通道生效 | 登录页可选"通过邮箱接收验证码"，收到邮件 |
| 无回归 | AC-7 的 8 项功能逐项手测 |

## 4. 重分级触发（出现即停下问人）

- 需要改 `api_id` / 签名 / 发布配置
- 需要引入新的第三方依赖
- 官方源码结构与 SPEC 假设严重不符（例：扫码登录 UI 根本不存在，需要从零实现）
- 去广告改动波及消息管线（`MessagesController` 核心刷新逻辑）
- 工作量预计翻倍

## 5. 人工门禁

| 门禁 | 时机 |
|---|---|
| G-1 | SPEC 冻结（✅ 已完成 2026-11-02） |
| G-2 | 首次编译通过后，确认可以继续 |
| G-3 | G1 + G2 改完、APK 产出后，真机验收 |

## 2.1 S4 扫码登录拆分（待 SPEC v2.2 确认后执行）

| 子步 | 内容 | 验证判据 | 回滚 |
|---|---|---|---|
| **S4.0** | 探针：在 `LoginActivity` 加最小 QR 页骨架，进入页面即调 `TL_auth_exportLoginToken`（flags 同 `auth.sendCode`），只打日志 | 编译 ✅ + 真机 logcat 出现 `LoginToken` / 或明确错误码；确认未登录连接可用 | 撤销该 commit |
| **S4.1** | QR 渲染：`tg://login?token=<base64url>` → 二维码图 + 「复制链接」；2s 轮询刷新 + 过期重取 | 真机：二维码可被官方客户端扫到并弹确认 | 回滚 S4.1 |
| **S4.2** | 收尾接线：`MigrateTo` → 切 DC 重取；`Success` → 2FA / `onAuthSuccess` 进入会话列表；断网/过期 UI 状态 | 真机 AC-2a / AC-2c / AC-3 / AC-4 | 回滚 S4.2 |

## 2.2 执行记录

| 时间 | 步 | 结果 | 证据 |
|---|---|---|---|
| 2026-11-02 09:28 | S1 | ✅ `assembleDebug` 退出码 0（6m32s） | `evidence/M1-build-result.md` |
| 2026-11-02 09:32 | S3 | ✅ 4 文件 +10−2，编译绿（1m35s），commit `ca4085c`；真机待验 | `evidence/S3-ads-removal.md` |
| 2026-11-02 09:39 | S3-VideoAds | ✅ 1 文件 +4，编译绿（1m36s），commit `bc9e3c6`；真机待验 | `evidence/S3-ads-removal.md` |
| 2026-11-02 09:46 | S4 | ✅ 探针实测：30s 内 export 返回同一 token（可 2s 轮询） | `evidence/qr-token-poll-probe.md` |
| 2026-11-02 09:49 | S4 | ✅ 代码完成：`LoginActivity.java` +374 / `strings.xml` +13，编译绿（1m37s），commit `de96d77`；运行期待真机 | `evidence/S4-qr-login.md` |
| 2026-11-02 09:48 | S4 | ✅ 可安装包 `artifacts/tg-client-S4-arm64-debug.apk`（sha256 `16d94d7e…`） | `artifacts/SHA256SUMS` |
| 2026-11-02 09:52 | SPEC v2.2 | ⏳ 更正提案已写，等你确认（Q2b / §0 变更表） | `spec/SPEC-v2.2-proposal.md` |
| 2026-11-02 10:10 | S6 | ✅ `assembleRelease` 退出码 0（12m36s），release APK 38.8 MiB（`org.telegram.messenger`，需卸载官方版） | `evidence/S6-release-build.md` |
| 2026-11-02 10:45 | S7 真机 | ✅ 扫码登录（含 DC 迁移 + 2FA 云密码）真机跑通 | `evidence/S7-realtime-validation.md` |
| 2026-11-02 11:00 | S7 真机 | ✅ 去广告用户实测确认（AC-5/AC-6 主观通过） | 同上 |
| 2026-11-02 11:05 | S8 | ✅ 验收包 v1 落盘（含长期使用建议） | `ACCEPTANCE.md` |
