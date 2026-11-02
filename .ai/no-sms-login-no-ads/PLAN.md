# 开发计划（PLAN v1，对应 SPEC v2.1）

> 依据：`evidence/frozen/SPEC-v2.1.md`（SPEC_BASE sha256 `5f03b94b...`）
> 代码目录：`/root/tg-client-code/telegram-src`（fork of `DrKLO/Telegram`，GPLv2）
> 隔离分支：`feat/no-sms-login-no-ads`

## 0. 已完成（M0）

| 项 | 结果 | 证据 |
|---|---|---|
| 扫码通道可用 | ✅ `auth.exportLoginToken` → `LoginToken` | `evidence/M0-spike-result.md` |
| 验证码通道 | ⏸ 本机 IP 触发 reCAPTCHA，待干净网络复测 | 同上 |

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
| **S1** | 建立隔离分支 + SPEC 入库 + 首次编译基线 | 仓库根、`local.properties` | `./gradlew :TMessagesProj_App:assembleDebug` 退出码 0 | `git checkout master` |
| **S2** | 源码勘察：定位登录链路与 sponsored 渲染点 | 无（只读） | 产出 `recon-source.md`，列出类名/方法名/行号 | 无改动 |
| **S3** | **G2 去广告**（改动小、独立可验证） | `TMessagesProj/src/main/java/org/telegram/messenger/MessagesController.java` 等（以 S2 结论为准） | 编译通过 + 真机 AC-5/AC-6 | 回滚 S3 提交 |
| **S4** | **G1-a 扫码登录**（主通道） | 登录 Activity/Fragment、布局、文案 | 编译通过 + 真机 AC-2 | 回滚 S4 提交 |
| **S5** | **G1-b 登录邮箱通道** | 同上 | 编译通过 + 真机 AC-5 | 回滚 S5 提交 |
| **S6** | Release 构建 + 签名 | `TMessagesProj_App/build.gradle`、keystore（不入库） | `./gradlew assembleRelease` 退出码 0 + APK 路径 | — |
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
