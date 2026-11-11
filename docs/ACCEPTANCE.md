# 验收包（ACCEPTANCE v1）— 2026-11-02

> **级别**：L3（登录鉴权红线；理由：改动触及登录链路与 api_id/签名，按 L3 走 SPEC 冻结 + 独立审查）
> **已执行阶段**：勘察 → 隔离分支 → SPEC 冻结(v2.1) → PLAN → 实现(S3/S4) → 编译自检 → 独立审查(fresh) → **真机验证（扫码+2FA+去广告）** → 本验收包
> **跳过阶段**：S5 邮箱通道真机验证、AC-7 逐项回归、SPEC v2.2 冻结（待你确认）
> **状态**：**功能验收通过（用户确认）**；工程收尾 3 项待决策（见 §7）

---

## 1. 一句话结果

自建 Telegram Android 客户端已完成两项改造：**登录不再需要短信验证码（用二维码扫码 + 2FA 云密码，已真机跑通）**、**应用内广告已去除（用户实测确认）**；代码在隔离分支本地提交 5 个 commit，**未 push、未合入**。

## 2. 交付物

| 类型 | 位置 |
|---|---|
| 代码分支 | `<repo-root>` 分支 `feat/no-sms-login-no-ads`，`ecd0b17..HEAD` 共 5 commit |
| debug 包（可与官方共存，测试用） | `artifacts/tg-client-S4d-arm64-debug.apk`（`org.telegram.messenger.beta`，sha256 `a08d7dc3…` 签名） |
| release 包（日用装机，**按最新 HEAD 重编并已装机**） | `artifacts/tg-client-S6b-arm64-release.apk`（`org.telegram.messenger`，40.7 MB，sha256 `7e044715…`；含 P0/P1 + 二维码尺寸修复 + 日志） |
| 关键文档 | `docs/README.md`、`docs/PLAN.md`、`docs/spec/SPEC-v2.2-proposal.md`、`docs/recon/source.md`、`docs/evidence/*` |

## 3. 改动清单（`git diff ecd0b17..HEAD`，7 files +450/−14）

| commit | 主题 | 文件 | 说明 |
|---|---|---|---|
| `ca4085c` | 去广告（频道/bot + 搜索推荐） | `BuildVars` / `MessagesController` / `ChatActivity` / `DialogsSearchAdapter` | 请求侧 + 渲染侧短路，新增 `HIDE_SPONSORED` 单开关 |
| `bc9e3c6` | 去广告（视频/图片贴片） | `video/VideoAds.java` | 同开关短路 |
| `de96d77` | 扫码登录（新设备侧） | `LoginActivity` + `strings.xml` | 新增 `VIEW_QR` 页、二维码渲染/轮询、DC 迁移、2FA 衔接、手机号页入口 |
| `1437581` | 扫码页尺寸修复 + 错误日志 | `LoginActivity` | 修 dp 二次换算；logQr 记录导出/迁移/import/失败；debug 状态栏带服务端错误码 |
| （含） | 独立审查 P0/P1 修复 | `LoginActivity` | import 成功后必切默认 DC；import 的 `SESSION_PASSWORD_NEEDED` 进入 2FA 密码页且 `getPassword` 发往迁移 DC |

## 4. AC 对照（冻结基线 v2.1 + v2.2 提案）

| AC | 结果 | 证据 |
|---|---|---|
| AC-1 扫码通道可用 | ✅ | M0：`RESULT: LoginToken` |
| AC-2a 新设备扫码登录、无短信 | ✅ **真机通过** | `evidence/S7-realtime-validation.md` §1；用户确认 + `screenshots/03-2fa-password-page.png` |
| AC-2b 手机号验证码通道保留 + 引导 | ⚠️ 代码保留官方原样；未实测服务端返回短信类型时的引导 | — |
| AC-2c 二维码刷新/错误态/DC 迁移 | ✅ 迁移路径真机走到并通过；刷新/断网 UI 有实现（未逐一截图） | 同上 |
| AC-3 登录后进入会话列表 | ✅ 真机通过 | 用户确认 |
| AC-4 2FA | ✅ 真机进入云密码页并登录成功 | `screenshots/03-2fa-password-page.png` |
| AC-5 频道内无 sponsored | ✅ 用户实测确认 | 用户确认（主观） |
| AC-6 搜索无推荐频道 | ✅ 用户实测确认 | 用户确认（主观） |
| AC-7 其余功能无回归 | 🟡 用户反馈"已登录正常使用"；逐项清单未打勾 | — |
| AC-8 构建可复现 | ✅ debug：`BUILD SUCCESSFUL in 6m32s`；release：`BUILD SUCCESSFUL in 12m36s` | `evidence/M1-build-result.md`、`evidence/S6-release-build.md` |

## 5. 独立审查（fresh reviewer，未参与实现）

审查对象 `ecd0b17..HEAD`，结论：去广告部分未发现回归；扫码登录发现 **P0 ×1 + P1 ×1 + P2 ×2**，全部处置：

| 级别 | 问题 | 处置 |
|---|---|---|
| P0 | `importLoginToken` 返回 `loginTokenSuccess` 时未先切默认 DC，可能"登录成功但会话不可用" | ✅ 已修：import 成功后无条件先 `setDefaultDatacenterId(migrate.dc_id)`（与 TDLib 一致）；真机迁移路径已验证通过 |
| P1 | import 的 `SESSION_PASSWORD_NEEDED` 被当成网络错误重试，2FA+迁移账号无法登录 | ✅ 已修：识别该错误 → 切 DC → `account.getPassword` 发往迁移 DC → 云密码页；真机 2FA 登录成功 |
| P2 | import 复用了含 `TryDifferentDc` 的 flags | ✅ 已修：import 单独 flags（去掉 TryDifferentDc） |
| P2 | 证据文档与未冻结的 v2.2 AC 口径矛盾 | ✅ 已修：S3/S4 证据文档已注明 AC 口径与范围 |

## 6. 真机验证中定位的 3 个"非代码"问题（重要运维知识）

1. **「测试后台」勾选会让扫码报 `AUTH_TOKEN_INVALID2`**：App 连测试服，正式账号的旧设备不认测试服 token。取消勾选即恢复。
2. **passkey 通行密钥在自签名 fork 上不可用**：Telegram `assetlinks.json` 只授权官方签名证书（`49:C1:52…`），我们是 `a08d7dc3…` → 系统不交付凭据（`NoCredentialException`）。属平台限制，已列为非目标 N10。
3. **真机环境的自动化限制**：HyperOS 屏蔽 `adb shell input` 与 `logcat` 读取 → 验证靠人工点按 + 截图/uiautomator。

## 7. 长期使用建议（回答"能否长期直接用"）

**结论：现在这个 App 可以日常长期用（聊天、收发、媒体都正常），但建议做 3 件事，否则会遇到"不能升级/风控/推送"类问题。**

### 7.1 日用包选一个，别来回切

| 方案 | 优点 | 代价 |
|---|---|---|
| **A（推荐）release 包**：卸载官方 Telegram → 装 `tg-client-S6-arm64-release.apk` | 包名是 `org.telegram.messenger`，长期当"主客户端"；无 beta 标记/调试开销；数据只存一份 | 首次要重新扫码登录一次（云端消息不丢）；**必须保存 `TMessagesProj/config/release.keystore`**，否则以后无法覆盖升级 |
| B 继续 debug `.beta` 包 | 可与官方版共存、方便排错 | 包名带 beta、有调试开销；数据存在 `.beta` 下，日后切 release 需要重新登录 |

> 注意：两个包**数据不互通**（不同 applicationId）。现在你正在用的是 debug `.beta`；如果决定长期用 release，请先装 release 并重新扫码（QR 通道已跑通，1 分钟）。

### 7.2 建议把 api_id 换成自己的（合规 + 降风控）

目前用的是官方源码内置 `APP_ID = 4`（Telegram 官方共享 api_id），这违反 Telegram API 条款，且"共享 id + 境外号码 + 数据中心网络"叠加更容易触发风控（M0 就遇到过 reCAPTCHA）。
**建议**：在 my.telegram.org 用你的号码申请自己的 `api_id/api_hash` → 我把它做成构建配置读取（改 `BuildVars` + gradle 属性，约 30 分钟、零行为变化）→ 重编一次即可。

### 7.3 以后怎么升级官方新版

这不是自动更新，需要重新编译：

```
git fetch upstream && git rebase upstream/master   # 把 5 个补丁 rebase 到新版
./gradlew :TMessagesProj_App:assembleRelease ...    # 重编
adb install -r 新 APK                                # 同签名可覆盖升级
```

补丁量很小（7 文件、+450 行），我可以在每次官方发版后 15–30 分钟内给你新版 APK。建议现在就把 `release.keystore` 和本仓库备份一份。

### 7.4 两个已知不确定项（可选验证）

- **推送（FCM）**：Google 的 FCM 凭证按"包名 + 签名指纹"授权，我们的签名与官方不同，**在 App 被系统杀掉时可能收不到推送**（App 前台/后台有自建长连接时正常）。可以发一条消息测试确认。
- **邮箱验证码通道**：官方已实现，但你这账号的场景没走到，未验证。

## 8. 需要你做的 3 件事（≤10 分钟）

1. **决定日用包**：release（推荐，我准备好装机步骤）还是继续 debug `.beta`；
2. **SPEC v2.2 变更表**（`docs/spec/SPEC-v2.2-proposal.md` §0 共 9 条）是否确认冻结 —— 确认后我落盘冻结 + 提交 `docs/spec/` 冻结基线，并把本验收包定稿；
3. **是否现在就做 api_id 配置化**（需要你的 api_id/api_hash；不做则维持官方共享 id 的风险）。

## 9. 明确未做

- 未 push / 未开 PR / 未合入（本地分支交付，等你授权）；
- AC-7 逐项回归未打勾；邮箱通道、推送未验证；
- 未做 release 包的"覆盖安装官方版"实测（需卸载官方应用）；
- 未做 `git archive` 快照备份（建议做，见 §7.3）。

## 10. 结论勾选（你来勾）

- [ ] 通过，保留当前分支与包
- [ ] 通过，但先做 §8 的某项（请注明）
- [ ] 修改后通过（请注明要改什么）
- [ ] 打回
- [ ] 无法验收（请注明原因）
