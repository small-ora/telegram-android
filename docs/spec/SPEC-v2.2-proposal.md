# 需求规格说明书（SPEC v2.2 · 更正提案）

> 项目代号：`tg-self-client`
> 状态：**⬜ 待你确认后冻结**（未确认前不进入 S4 实现）
> 前序基线：v2.1 已冻结（`.ai` commit `ecd0b17`，sha256 `5f03b94b…`，见 `evidence/frozen/SPEC_BASE.txt`）
> 分级：**L3**（登录鉴权链路，红线）
> 依据：`recon/source.md`（S2 源码勘察，2026-11-02）

---

## 0. v2.1 → v2.2 变更（old → new，逐条需你确认）

| # | 项 | v2.1（old） | v2.2（new） | 依据 |
|---|---|---|---|---|
| 1 | §3.3 技术立足点 | 「`CodeSettings.allow_app_hash` 让服务端返回 `SentCodeTypeApp`（验证码作为服务消息送达已登录会话）」 | **更正**：`allow_app_hash` 是 **Android SMS Retriever 的 app hash**（让 App 自动读短信验证码），与「服务端选哪条投递通道」无关。投递通道由服务端策略决定，**客户端不可强制**。 | `LoginActivity:3082/3123-3127`、`BuildVars:95`（11 位 hash）、`SmsReceiver:34-51` |
| 2 | G1 主路径 | 扫码（已验证）+ 邮箱；App 内验证码为备用 | **不变，但理由更新**：扫码 = 唯一「客户端可控 + 已实测可用」；邮箱 = 官方已实现（白送）；App 内验证码 = 不可强制，仅当服务端恰好返回时官方 UI 可用 | `recon/source.md` §1.2、§1.4 |
| 3 | AC-1b | 待测：`app_hash` 模式返回 `SentCodeTypeApp` | **不再作为 G1 验收门槛**，降级为「非阻塞观察项」；不再为它单独阻塞里程碑 | 同上 |
| 4 | AC-2 | 输入 +86 号码后不出现 SMS Fee 页面，旧设备 3 分钟内收到 `Login code: XXXXX` | **拆为 AC-2a / AC-2b / AC-2c**（见 §4） | 技术方案变化 |
| 5 | AC-3 | 输入验证码后成功登录并进入会话列表 | **扫码确认后**进入会话列表（与 AC-2a 同一次真机验证，独立勾选） | 同上 |
| 6 | AC-4 | 2FA 照常校验 | 保留；补充：扫码成功后若账号开启 2FA，**必须**进入云密码页，密码正确才完成登录 | `LoginActivity:3452-3470`、`TL_auth_authorization.password_pending` |
| 7 | AC-5 / AC-6 | 频道内无 sponsored message；会话列表无 sponsored peer | 不变（已实现，见 `evidence/S3-ads-removal.md`）；补充副作用：bot 内广告随同源请求一并消失 | commit `ca4085c` |
| 8 | 非目标（新增） | — | **N8**：登录页除「新增扫码入口 + 二维码页」外，手机号输入 UI 与官方保持原样；**N9**：本版不动「视频/图片查看器贴片广告（`VideoAds`）」、不动 Premium 推广页与频道变现页（是否动见 §5 Q3） | 控制范围 |
| 9 | 旧设备兼容 | （v2.1 未涉及）「复制链接」可让旧设备点开 | **更正**：深链 `tg://login?token=…` 在官方客户端（含本 fork）**只弹提示、不会完成登录**（`LaunchActivity:4120-4126`）。因此「复制链接」仅为引导/排障，**旧设备仍必须扫码** | 源码勘察（2026-11-02） |

> 变更规则：以上任一条你只接受部分，请指出第几条；确认后本文转正为 v2.2 冻结基线。

---

## 1. 目标（两条，措辞微调）

| ID | 目标 | 一句话 |
|---|---|---|
| **G1** | **登录不走短信验证码** | 新设备登录时可选「扫码登录」（主通道，已实测可用）或「登录邮箱」（官方已实现）；手机号验证码通道保留官方原样，若服务端要收短信费则引导改用上述通道；**全程不购买 Premium、不付短信费** |
| **G2** | **去除应用内广告** | 去掉频道内 sponsored message 与搜索推荐频道（sponsored peer），不改变其他行为 |

---

## 2. 非目标

| ID | 非目标 |
|---|---|
| N1–N7 | 沿用 v2.1 |
| **N8** | 不重排手机号登录 UI（只加「通过二维码登录」入口 + 新增二维码页） |
| **N9** | 不动 `VideoAds`（视频/图片贴片广告）、`PremiumPreviewFragment`（Premium 推广页）、`ChannelMonetizationLayout`（频道变现页），除非 Q3 确认 |

---

## 3. 技术方案（G1-a 扫码登录，设计稿）

### 3.1 官方源码里已有什么（白送）

| 能力 | 位置 | 状态 |
|---|---|---|
| 旧设备「扫码批准登录」全链路 | `SessionsActivity.openCameraScanActivity`（`SessionsActivity.java:1219+`）、`CameraScanActivity` `TYPE_QR_LOGIN`（`:1387`）、`LaunchActivity` 处理 `tg://login?token=` 链接（`:2548`、`:3240` 解码 + `auth.importLoginToken`） | ✅ 已实现（官方 web/desktop 登录用） |
| TL 类 | `TL_auth_exportLoginToken`（`TLRPC.java:51810`）、`TL_auth_loginToken{expires,token}`（`:18603`）、`MigrateTo{dc_id,token}`（`:18621`）、`Success{authorization}`（`:18639`） | ✅ 代码生成完整 |
| 二维码渲染 | `TelegramQRCodeWriter`、`QRCodeBottomSheet`、`QrCodeLayer` 等 | ✅ 有（选型见 S4 勘察） |
| 邮箱验证码登录 | `LoginActivity:1933` + `VIEW_CODE_EMAIL` / `VIEW_CODE_EMAIL_SETUP` + `LoginActivityEmailCodeView` | ✅ 已实现 |
| 云密码（2FA）页 | `VIEW_PASSWORD` + `LoginActivityPasswordView` + `SESSION_PASSWORD_NEEDED` 处理（`LoginActivity:3452`） | ✅ 已实现 |

### 3.2 缺什么（要我们写）

| 能力 | 证据 | 预估 |
|---|---|---|
| 新设备调用 `auth.exportLoginToken` 并轮询 | 全项目**零调用**（`recon/source.md` §1.4） | 中 |
| 登录页展示二维码 + 刷新 + 复制链接 | 需新增一个 `SlideView` 子页面（结构参照 `LoginActivityEmailCodeView`） | 中 |
| `loginTokenMigrateTo` 的 DC 迁移、`loginTokenSuccess` 衔接 2FA / `onAuthSuccess` | 需按现有 `PHONE_MIGRATE` / `SESSION_PASSWORD_NEEDED` 范式实现 | 中 |

### 3.3 流程（提案）

```
新设备（未登录）                              旧设备（已登录，官方/自建均可）
  │ 1. 登录页点「通过二维码登录」                    │
  │ 2. auth.exportLoginToken(api_id, api_hash) ──→  │
  │    ← TL_auth_loginToken{token, expires}        │
  │ 3. 渲染 QR: tg://login?token=<base64url(token)> │
  │    + 「复制链接」                              │
  │ 4. 每 2s 重新 exportLoginToken（刷新 token）    │
  │    ├ MigrateTo{dc_id} → 迁移 DC 后重发 export   │
  │    ├ loginToken → 继续轮询                     │
  │    └ Success{authorization} ────────────────→ 设置 → 设备 → 扫码登录（已有功能）
  │ 5. authorization.password_pending?              │ 扫描 → 确认
  │    ├ 是 → 云密码页（VIEW_PASSWORD）            │
  │    └ 否 → onAuthSuccess → 会话列表             │
```

### 3.4 错误与边界

| 场景 | 处理 |
|---|---|
| 令牌过期（`expires`） | 自动重新 `export` 并刷新二维码（用户无感） |
| 旧设备扫到的是已刷新的旧 token | 服务端返回过期/无效 → 重新 `export`，UI 提示「请重新扫码」 |
| `loginTokenMigrateTo` | 迁移 DC → 用返回的 token 重新 `export` |
| 网络错误 / 超时 | 指数退避重试（3s 起，最多 5 次），UI 显示可点击重试 |
| 页面切走 / App 后台 | 停止轮询；回前台恢复 |
| 账号开启 2FA | 进入现有云密码页，密码正确才完成登录 |
| 旧设备无摄像头 / 不方便扫码 | 「复制链接」→ 旧设备在聊天/浏览器打开 `tg://login?token=…`（`LaunchActivity` 已支持） |

### 3.5 风险（在 v2.1 风险表基础上新增）

| ID | 风险 | 缓解 |
|---|---|---|
| R6 | 未登录连接上发 `exportLoginToken` 被拒（native 侧对 `currentUserId==0` 的请求默认不发送，会进 `waitingLoginRequests`） | **已定位解法**：必须带 `RequestFlagWithoutLogin`（`RequestFlagEnableUnauthorized` 等），与 `auth.sendCode` 完全一致（见 §3.6）。剩余风险降为「运行时行为需真机确认」 |
| R7 | DC 迁移（`loginTokenMigrateTo`）处理不完整 → 扫码后卡住 | 已有先例可抄：`PasskeysController` 用 `setDefaultDatacenterId(dc_id)` + 带 `datacenterId` 的 `sendRequest` 完成未登录态跨 DC（见 §3.6） |
| R8 | 刷新与扫码竞态 | 服务端对旧 token 返回过期，自动重取；UI 提示「请重新扫码」 |
| R9 | 复用 `onAuthSuccess` 时账户切换分支（`newAccount`）误触发 | 走 `newAccount=false` 路径；真机验证 |
| R10 | 与官方客户端互通性（官方码能否被本客户端扫、本客户端的码官方能否扫） | 二维码内容就是标准 `tg://login?token=`；两侧都走官方同一套 `SessionsActivity`/`acceptLoginToken` 逻辑 → 理论互通；S7 真机双向验证 |
| R11 | **真机验证依赖**：AC-2a/AC-3/AC-4 需要一台「已登录的旧设备」扫码 | 见 §5 Q5；若只有一台设备，需另找一台（或先用本客户端+官方客户端互扫） |

### 3.6 S4 的关键技术前提（本次勘察已确认，附证据）

| # | 结论 | 证据 |
|---|---|---|
| 1 | 未登录态发鉴权类请求**必须带 flags**，否则 native 会把请求挂起不发送（`currentUserId==0` → `waitingLoginRequests`） | `jni/tgnet/ConnectionsManager.cpp:1906、2034`；`Defines.h:171` |
| 2 | `auth.sendCode` 用的 flags 就是模板：`RequestFlagFailOnServerErrors \| RequestFlagWithoutLogin \| RequestFlagTryDifferentDc \| RequestFlagEnableUnauthorized` | `LoginActivity.java:3305`（sendCode 的 sendRequest 尾部 flags） |
| 3 | 未登录态跨 DC 有现成先例：`getCurrentDatacenterId()` / `getCurrentAuthKeyId()` → `setDefaultDatacenterId(dc_id)`（内部 `native_moveDatacenter`）→ 再发请求 | `PasskeysController.java:246-258`；`ConnectionsManager.java:744-746` |
| 4 | 登录成功后的收尾必须调用 `onAuthSuccess(TLRPC.TL_auth_authorization)`（做 userId/UserConfig/MessagesStorage 全套初始化）；`TL_auth_loginTokenSuccess.authorization` 正是该类型（字段为 `auth_Authorization`，需 downcast） | `LoginActivity.java:1652-1680`、`TLRPC.java:18639` |
| 5 | 2FA：`TL_auth_authorization.password_pending` 为真（或 `SESSION_PASSWORD_NEEDED` 错误）→ 进入 `VIEW_PASSWORD` | `LoginActivity.java:3452-3470`（`SESSION_PASSWORD_NEEDED` 分支）、`SessionsActivity` 中 `password_pending` 用法 |
| 6 | 二维码内容编码：旧设备解码端先做 `/?→_ +?→-` 再 `Base64.URL_SAFE` 解码；因此编码端用 `Base64.encodeToString(token, Base64.URL_SAFE \| Base64.NO_WRAP \| Base64.NO_PADDING)` 即可（不会产生 `+/`） | `SessionsActivity.java:1255-1260`、`LaunchActivity.java:3240` |
| 7 | 新页面挂靠方式：`views` 数组 + `@ViewNumber` 常量，实例化在 `LoginActivity` 的 `onFragmentCreate`（`views[VIEW_*] = new ...`），首屏固定 `views[0]`（`VIEW_PHONE_INPUT`） | `LoginActivity.java:322（views[19]）`、`:294-313（IntDef）`、`:669-687（实例化）` |
| 8 | `loginTokenMigrateTo` 不切主 DC，而是**向 `dc_id` 发 `auth.importLoginToken(token)`**（成功后再切默认 DC） | TDLib 同仓库实现 `jni/td/td/telegram/AuthManager.cpp:1222-1244`；`ConnectionsManager.setDefaultDatacenterId` 会清当前 DC 请求（native `ConnectionsManager.cpp:3496-3505`） |
| 9 | 扫码登录的 2FA **不是** `TL_auth_authorization.password_pending`（该字段只存在于 `TL_authorization`），真信号是 401 `SESSION_PASSWORD_NEEDED` → `account.getPassword` → `VIEW_PASSWORD` | `TLRPC.java:2768-2808`；`LoginActivity.java:3201-3221`；TDLib `AuthManager.cpp:1571-1583` |
| 10 | 轮询实测：30s TTL 内多次 `export` 返回**同一 token**（去重 1/4），TTL 逐次递减 → 可每 2s 轮询且不必每次重绘二维码 | `evidence/qr-token-poll-probe.md`（Telethon 实测 2026-11-02） |

---

## 4. 验收标准（AC v2.2 提案）

| ID | 验收标准 | 验证方式 |
|---|---|---|
| AC-1 | 扫码通道可用：`auth.exportLoginToken` 返回 `LoginToken` | ✅ 已验证（M0，`RESULT: LoginToken`） |
| AC-1b | ~~App 内验证码通道~~ → **非阻塞观察项**（不再作为验收门槛） | 条件具备时复测，不阻塞 |
| **AC-2a** | 新设备登录页可见「通过二维码登录」入口；点击后显示二维码与可复制的 `tg://login?token=…` 链接（**链接仅作引导：官方客户端点开深链只会提示去扫码，不能替代扫码**）；**旧设备用「设置 → 设备 → 扫码登录」扫码确认后，新设备在令牌有效期内自动完成登录并进入会话列表**；全程无短信、无「短信费用」页 | 真机 + 新旧设备截图 |
| **AC-2b** | 手机号验证码通道保持官方原样；若服务端返回短信/付费类型，App 给出「改用二维码或邮箱登录」引导，不静默失败 | 真机截图 |
| **AC-2c** | 二维码自动刷新（≤30s）；令牌失效/被拒/断网时 UI 有明确状态且可重试；跨 DC 迁移用户无感 | 真机（含断网、等待过期场景） |
| AC-3 | 扫码确认后成功进入会话列表（AC-2a 的独立勾选项） | 真机 |
| AC-4 | 若账号开启 2FA：扫码成功后进入云密码页，密码正确才完成登录；密码错误被拒 | 真机 |
| AC-5 | 频道内不再出现 sponsored message | 真机 + 前后对比截图（代码已改，待真机） |
| AC-6 | 会话列表/搜索结果不再出现 sponsored peer（推荐频道） | 真机 + 前后对比截图（代码已改，待真机） |
| AC-7 | 官方其余功能无回归（收发消息、图片视频、语音、设置、通知、搜索、群组、频道订阅） | 真机清单逐项打勾 |
| AC-8 | 构建可复现：一条命令产出 arm64-v8a APK，记录 JDK/NDK/Gradle 版本 | debug 已绿（`evidence/M1-build-result.md`）；release 留 S6 |

---

## 5. 待你决策（Q1–Q5）

> 每项都给了推荐选项；你回「Q1=A、Q2=…、Q3=…」即可，我据此冻结 SPEC 并开工。

| ID | 问题 | 选项 | 建议 | 你的选择（2026-11-02） |
|---|---|---|---|---|
| **Q1** | 二维码登录在登录页的**形态** | **A. 首屏仍是手机号输入，底部加「通过二维码登录」文字入口（改动最小、与官方一致）**<br>B. 首屏默认显示二维码（像 Telegram Desktop），手机号登录降为二级入口<br>C. 两步：首屏两个大按钮「手机号登录 / 扫码登录」 | **A** | ✅ **A**（已按此实现） |
| **Q2** | 旧设备兼容方式 | **A. 二维码页提供「复制链接」按钮**<br>B. 不做，只能扫码<br>C. 再加「手动输入验证码」入口 | **A** | ✅ **A**（已实现）——**但源码勘察发现链接不能完成登录**（官方客户端只会弹「去扫码」提示）。是保留（仅引导/排障）还是去掉？→ **Q2b** |
| **Q2b** | 「复制登录链接」按钮保留否 | **A. 保留**（页面上标注「需旧设备扫码」提示，避免误解）<br>B. 去掉（二维码页更简洁） | **A** | ⏳ 待你定 |
| **Q3** | 视频/图片查看器的**贴片广告**（`VideoAds`）是否一并去掉？ | **A. 一并去掉**（独立 1 文件 commit）<br>B. 本次不动 | **A** | ✅ **A**（已实现，commit `bc9e3c6`） |
| **Q4** | 真机验证怎么安排？ | **A. adb 连到本机**<br>B. 你手动 sideload 自测<br>C. 先只做代码 | **A 最好**，否则 B | ✅ **C（先只做代码）**；APK 已备好，随时可切 B/A |
| **Q5** | 你是否有「已登录 Telegram 的手机」可用于扫码验证？ | **A. 有，随时配合**<br>B. 只有一台手机<br>C. 没有真机 | — | ✅ **A** |

---

## 6. 确认后的冻结动作（我来做）

1. 本文转正为 `docs/spec/SPEC-v2.2-proposal.md`；
2. 复制到 `docs/spec/SPEC-v2.2-frozen.md` 并更新 `docs/evidence/frozen/SPEC_BASE.txt`（sha256 + 时间 + 确认依据）；
3. 同步 `docs/spec/SPEC-v2.2-frozen.md`，本地提交 `chore(spec): freeze SPEC v2.2`；
4. 更新 `PLAN.md`（S4/S5 步骤细化），随后开始 S4 的第一步「`exportLoginToken` 可行性探针」。
