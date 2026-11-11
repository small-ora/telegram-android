# 真机运行期验证记录（2026-11-02，S7 进行中）

> 设备：Xiaomi 24129PN74C（HyperOS 4.0 / Android 17 / arm64-v8a），通过 PVE USB 直通接入本机。
> 安装包：`artifacts/tg-client-S4d-arm64-debug.apk`（`org.telegram.messenger.beta`，可与官方版共存）。
> 本文件记录真机实测结论，截图在 `docs/evidence/screenshots/`。

## 1. 已通过的运行期验证

| 项 | 结果 | 证据 |
|---|---|---|
| 安装 / 启动 / 中文界面 | ✅ | `screenshots/00-intro.png` |
| 登录页出现「通过二维码登录」入口 | ✅ | `screenshots/04-passkey-dialog-testbackend.png`（页面下半部分可见入口） |
| **未登录态 `auth.exportLoginToken` 真机可用**（R6 风险解除） | ✅ 二维码正常生成，状态「等待手机端确认…」持续轮询 | `screenshots/02-qr-fixed.png` |
| **扫码登录全链路（AC-2a / AC-3）** | ✅ **通过**：旧设备扫码确认 → 服务端 `loginTokenMigrateTo` → `importLoginToken` → 进入云密码页 → 输入密码后**登录成功进入会话列表**（用户确认） | `screenshots/03-2fa-password-page.png` + 用户确认 |
| **2FA（AC-4）** | ✅ 该账号开启了两步验证：扫码后正确进入官方云密码页（`SESSION_PASSWORD_NEEDED` 分支），密码校验通过后完成登录 | `screenshots/03-2fa-password-page.png` |
| QR 页布局 | ✅ 修复 dp 二次换算后正常（修复前：二维码 2324px 高、标题被挤出屏幕） | `01-qr-broken-size.png` → `02-qr-fixed.png` |
| **去广告 AC-5 / AC-6** | ✅ **用户实测确认「没有再看到广告」**（频道内 sponsored 与搜索推荐频道；用户主观确认，未做官方客户端前后对比截图） | 用户确认（2026-11-02 11:0x） |

> 说明：`loginTokenMigrateTo → importLoginToken` 这条 DC 迁移路径在真机上被实际走到并通过，说明独立审查提出的 P0 修复方向（迁移后切默认 DC）与实际协议一致。

## 2. 踩到的两个坑（已定位，非代码 bug）

### 2.1 旧设备扫码报 `AUTH_TOKEN_INVALID2` —— 原因是 App 勾了「测试后台」

`LoginActivity` 的手机号页在 debug 构建下会显示「测试后台」复选框（`testBackend`）。勾上后 App 连的是
Telegram **测试服务器**，而扫码的旧设备是正式账号 → 测试服的登录 token 在正式服不存在，扫码即报
`AUTH_TOKEN_INVALID2`（注意：过期是 `AUTH_TOKEN_EXPIRED`，不是同一个错）。

**取消勾选后扫码立即通过**。这是排查时最容易误判成"二维码协议不通"的地方，写入验收/运维清单。

### 2.2 通行密钥（passkey）登录在自签名 fork 上**不可用**（平台限制，非代码缺陷）

Telegram 的 `assetlinks.json`（`https://telegram.org/.well-known/assetlinks.json`）为 passkey 授权了这些 App 签名：

| 包名 | 允许的证书 SHA-256 |
|---|---|
| `org.telegram.messenger` | `49:C1:52:25:…:4D:CC:38:E1` |
| `org.telegram.messenger.web` | 同上 |
| `org.telegram.messenger.beta` | 同上 |
| `org.thunderdog.challegram` | `EB:80:1A:30:…:90:DC:DD:33` |

而我们自编译的 APK（debug 与 release 都是仓库自带 `TMessagesProj/config/release.keystore` 签名）：

```
Signer #1 certificate SHA-256: a08d7dc323ddf71ef3201944397e0d3cce7d40847263e11f328b68bbe19229ab
```

**证书指纹不在 assetlinks 白名单里** → Android Credential Manager 不会把 Telegram 的 passkey 交给我们的 App
（即使包名恰好是 `org.telegram.messenger.beta`，关联校验看的是证书指纹），代码里最终拿到的是
`NoCredentialException`（被映射成 `EMPTY` 静默返回），所以表现为"点了没反应/失败"。

**结论**：passkey 通道无法在自签名 fork 上启用；要启用只能使用 Telegram 官方签名私钥（不可得，也不应使用）。
这不影响 G1——扫码通道已实测跑通，且不需要 passkey。

## 3. 测试环境限制（影响自动化，记录备查）

| 限制 | 现象 | 绕过方式 |
|---|---|---|
| HyperOS 禁止 shell 注入输入事件 | `adb shell input tap/keyevent` 报 `INJECT_EVENTS` 权限不足；`sendevent` 被 SELinux 拒绝 | 人工在手机上点按；`adb shell cmd power wakeup` + `wm dismiss-keyguard` 可唤醒 |
| `logcat` 读不到 | `adb logcat -d` 返回 0 行 | 用 `uiautomator dump` 读文案 + `screencap` 截图作为证据；代码里 `Log.e("DSHQR")` 在该机型上也读不到 |
| 锁屏需 PIN/指纹 | 屏幕熄灭后无法用 adb 解锁 | 人工解锁 |

## 4. 待完成

- ~~AC-5 / AC-6 去广告的真机取证~~ → **用户已确认通过**（主观验收）
- AC-7 回归抽查（用户反馈"已登录正常使用"，逐项清单未逐条打勾）
- 长期间日用建议：见 `docs/ACCEPTANCE.md`（release 包 + 自有 api_id + 升级方式）
- 可选：推送（FCM）与邮箱通道的真机验证
- 若要交付 release 包：用 `artifacts/tg-client-S6-arm64-release.apk` 覆盖安装（需先卸载官方版）
