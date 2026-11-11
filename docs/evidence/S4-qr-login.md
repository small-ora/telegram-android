# S4 扫码登录（G1-a）实现记录（2026-11-02）

> 结论：**代码已完成并本地提交**（commit `de96d77`，含独立审查后的修复 commit），`assembleDebug` 退出码 0。
> **运行期验证未做**：当前无 adb 设备（`adb devices` 为空）。
>
> **AC 口径说明（重要）**：冻结基线 SPEC v2.1 只有 **AC-1**（`exportLoginToken` 返回 `LoginToken`，M0 已验证）。
> 本页涉及的「二维码页 / DC 迁移 / 2FA / 复制链接」对应的 **AC-2a / AC-2c / AC-3 / AC-4 仅存在于 `spec/SPEC-v2.2-proposal.md`，尚未冻结**。
> 因此本页只声明「代码完成 + 编译通过」，**不声明任何 AC 通过**；AC 判定需你先确认 v2.2 冻结，再做真机。

## 1. 改动清单（2 文件 / +384 −3）

| 文件 | 改动 |
|---|---|
| `TMessagesProj/src/main/java/org/telegram/ui/LoginActivity.java` | 新增 `VIEW_QR` 页与 `LoginActivityQrView`；`views[20]`；`onPause` 停轮询；`onBackPressed` 加 QR 分支；`PhoneView` 底部加「通过二维码登录」入口 + 主题色 |
| `TMessagesProj/src/main/res/values/strings.xml` | 新增 12 条私有文案（`LoginQr*`，中文直写：远程语言包不含这些 key） |

完整 diff：`git show de96d77` / `git diff bc9e3c6..de96d77`

## 2. 实现要点（为什么这么写）

| 要点 | 实现 | 依据 |
|---|---|---|
| 未登录态发请求 | `RequestFlagFailOnServerErrors \| WithoutLogin \| TryDifferentDc \| EnableUnauthorized`（与 `auth.sendCode` 完全一致） | native `jni/tgnet/ConnectionsManager.cpp:1906`：`currentUserId==0` 且无 `WithoutLogin` 的请求会被挂起不发；`LoginActivity:3246` 是官方模板 |
| 轮询节奏 | 每 2s 一次 `export`；**token 未变化时复用同一张二维码图**，变化才重绘；失败退避 2s→4s→8s→16s，`FLOOD_WAIT_X` 按其秒数等待 | 实测见 `evidence/qr-token-poll-probe.md`（30s TTL 内 token 不变） |
| DC 迁移 | 收到 `loginTokenMigrateTo` 后，向 `dc_id` 发 `auth.importLoginToken(token)`（显式 dcId + unauth flags），成功后再 `setDefaultDatacenterId(dc_id)` 并继续轮询 | TDLib 同仓库实现 `jni/td/td/telegram/AuthManager.cpp:1222-1244`（迁移用 import 而不是直接切主 DC）；`ConnectionsManager.setDefaultDatacenterId` 会清当前 DC 请求，故放在响应之后再切 |
| 登录成功 | `loginTokenSuccess.authorization` → 判 `TL_auth_authorization` 且 `user != null` → 复用 `onAuthSuccess()`（做 userId/UserConfig/MessagesStorage 全套初始化） | `LoginActivity:1652-1684`；`SignUpRequired` 等异常只提示不静默 |
| 2FA | `SESSION_PASSWORD_NEEDED` → `account.getPassword` → 序列化塞 `password` bundle → 官方 `VIEW_PASSWORD` 页 | `TLRPC.TL_auth_authorization` **没有** `password_pending` 字段；官方真入口是 401 错误（`LoginActivity:3201-3221`、`3452-3470`；TDLib `AuthManager.cpp:1571-1583`） |
| 二维码内容 | `"tg://login?token=" + Base64.encodeToString(token, URL_SAFE \| NO_WRAP)`（保留 `=` padding、用 URL_SAFE 字母表） | 旧设备解码 `SessionsActivity:1258-1263` 用 `Base64.URL_SAFE` 且未传 `NO_PADDING`；`CameraScanActivity:1387` 逐字校验前缀 |
| 生命周期 | `onShow/setParams` 启动、`onHide/onPause/onDestroyActivity/onBackPressed` 停止并 `cancelRequest`；回调先判 `polling && !destroyed` | `setPage` 只调 `onHide` 不取消请求（`LoginActivity:1551/1566`）；`LoginPayView` 是官方同类范式 |
| 页面挂载 | `views` 数组 19→20、`@ViewNumber` 加 `VIEW_QR=19`、`createView` 实例化；**不**加入浮动按钮白名单 | 官方页面机制见 `recon/source.md` / 勘察报告 A 节 |

## 3. 已知限制（需你知晓 / 决策）

1. **「复制登录链接」本身不能完成登录**：官方客户端（含本 fork）对 `tg://login?token=…` 深链只弹提示「去 设置→设备→扫码二维码」，**没有**「点链接即同意」的能力（`LaunchActivity:4120-4126`、`strings.xml:2765`）。所以复制按钮实际只是**引导/排障**用途，旧设备仍必须用相机扫码。若你不想保留这个容易误解的按钮，我可以去掉（一行改动）。
2. 旧设备「从相册选二维码」同样不可用：所有 `CameraScanActivity.showAsSheet` 调用都传 `gallery=false`（含 `SessionsActivity:1220`）。对「扫码确认」场景意义不大（码在新设备屏幕上），未改。
3. 2FA 分支是**防御性实现**：正常二维码登录通常由旧设备授权、无需输入密码；只有服务端返回 `SESSION_PASSWORD_NEEDED` 才会进密码页。该分支未在真机验证。
4. 文案为中文直写（`values/strings.xml` 默认语言）：Telegram 的远程语言包不含新 key，写中文可保证显示；代价是切英文界面时这 12 条仍显示中文。

## 4. 验证证据

| 项 | 结果 |
|---|---|
| 编译命令 | `./gradlew :TMessagesProj_App:assembleDebug -Pandroid.injected.build.abi=arm64-v8a -Dorg.gradle.jvmargs=-Xmx4g --max-workers=6 --console=plain` |
| 退出码 | **0**，`BUILD SUCCESSFUL in 1m 37s` |
| 日志 | `docs/evidence/logs/build-S4-20261102-094843.log` |
| 产物 | `TMessagesProj_App/build/intermediates/apk/afat/debug/app.apk`（68.0 MiB） |
| 可安装包 | `<repo-root>/artifacts/tg-client-S4-arm64-debug.apk`（sha256 `16d94d7e…`，包名 `org.telegram.messenger.beta`，可与官方版共存） |
| 运行期 | ❌ 未做（无设备）：需真机验证 AC-2a / AC-2c / AC-3 / AC-4 |

## 5. 真机验证步骤（等设备就绪后照做）

1. `adb install -r artifacts/tg-client-S4-arm64-debug.apk`
2. 打开 App → 登录页底部点「通过二维码登录」→ 应看到二维码 + 倒计时状态
3. 用**已登录 Telegram 的手机**：设置 → 设备 → 扫码登录 → 扫该二维码 → 确认
4. 预期：新设备 2 秒内进入会话列表；全程无短信、无短信费用页（AC-2a / AC-3）
5. 异常场景：等待 30s 观察二维码自动刷新（AC-2c）；断网观察重试提示；若账号开了 2FA 观察是否进密码页（AC-4）
6. 抓日志：`adb logcat -s Telegram FileLog | grep -i "qr\|loginToken"`（debug 版默认开日志）

## 6. 回滚

```bash
git revert --no-edit de96d77
```
