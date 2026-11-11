# 源码勘察（S2）

> 代码基线：`DrKLO/Telegram` 13.1.1 (build 7237)，commit `3de37c8`
> 分支：`feat/no-sms-login-no-ads`，SPEC 基线 commit `ecd0b17`
> 勘察方式：只读 grep + 阅读调用点，未修改任何文件

---

## 一、G1 登录链路

### 1.1 重要更正：`allow_app_hash` 不是「App 内接收验证码」开关

`LoginActivity.java:3082`：

```java
settings.allow_app_hash = settings.allow_firebase =
    PushListenerController.GooglePushListenerServiceProvider.INSTANCE.hasServices();
```

**证据链**：

| 证据 | 位置 | 说明 |
|---|---|---|
| `getSmsHash()` 返回 11 位硬编码串 | `BuildVars.java:95` | `"w0lkcmTZkKh"` / `"O2P2z+/jBpJ"` / `"oLeq9AcOZkT"` —— 典型的 Android SMS Retriever hash 格式 |
| `SmsRetriever.SMS_RETRIEVED_ACTION` + 正则提码 | `SmsReceiver.java:34-51` | 用 `sms_hash` 校验并自动读取短信里的验证码 |
| `settings.allow_app_hash` 为真时才写入 `sms_hash` | `LoginActivity.java:3123-3127` | 二者强绑定 |

**结论**：`allow_app_hash` 的语义是「允许服务端在**短信**里带上 app hash，让 App 自动读取」，
**与 `sentCodeTypeApp`（验证码作为服务消息投递到已登录会话）无关**。

这推翻了我此前在对话中的判断（原判断：该开关是 App 内验证码通道）。SPEC 需出 v2.2 更正。

**附带结论**：官方客户端在**无 Google Play 服务**的设备上该开关恒为 false，
所以自动读短信也失效——但这不改变「服务端选择哪条通道」这一层。

### 1.2 服务端如何决定 `sentCodeTypeApp`

不由客户端开关控制，由服务端按自身策略判定。Telegram 官方 FAQ 表述为
「我们**可能**把登录验证码发到 Telegram 而不是短信」，auth 文档描述该类型为
「一条发给**所有其他已登录会话**的服务通知」。

**推论**：这条通道对本项目**不是可强制的**，只能"尽量让它发生"或改用不依赖它的通道。

### 1.3 已实现的部分（白送）

| 能力 | 位置 | 状态 |
|---|---|---|
| 处理 `sentCodeTypeApp`（App 内验证码页） | `LoginActivity:1898` → `VIEW_CODE_MESSAGE` | ✅ 已有 |
| **处理 `sentCodeTypeEmailCode`（邮箱验证码）** | `LoginActivity:1933`、`VIEW_CODE_EMAIL`、`VIEW_CODE_EMAIL_SETUP`、`LoginActivityEmailCodeView` | ✅ **已完整实现** |
| 二维码编码能力 | `TelegramQRCodeWriter.java`、`QrCodeLayer`、`QRCodeBottomSheet` | ✅ 有 |
| 二维码扫描能力 | `QRScanner`、`CameraScanActivity`、`QrScanOverlay` | ✅ 有 |

### 1.4 缺失的部分（要我们写）

| 能力 | 证据 | 工作量 |
|---|---|---|
| **新设备显示二维码登录** | `TL_auth_exportLoginToken` / `TL_auth_importLoginToken` 仅在 `TLRPC.java:51810/51829` 有类定义，**全项目零调用** | 中：需实现 轮询 exportLoginToken + 渲染 QR + 处理 migrate/success + 展示 `tg://login?token=` 链接 |
| `sentCodeTypeSms` / `FragmentSms` 时的引导 | 现有逻辑直接进短信页 | 小：检测到付费类型时提示改用二维码 |

**G1 工作量重估**：
- G1-b（邮箱验证码）：≈ 0（官方已实现），最多调入口可见性
- G1-a（扫码登录）：需要新写，是 G1 的主要工作量

---

## 二、G2 去广告

### 2.1 频道内 sponsored message（主要广告形态）

| 位置 | 作用 |
|---|---|
| `MessagesController.java:21669` `getSponsoredMessages(long dialogId)` | 发 `messages.getSponsoredMessages` 请求并缓存 |
| `ChatActivity.java:25207` `addSponsoredMessages(boolean animated)` | 取缓存结果并插入到消息列表 |
| `ChatActivity.java:25208` | 已有短路条件：`... \|\| getUserConfig().isPremium() && getMessagesController().isSponsoredDisabled() \|\| ...` |
| `MessagesController.java:24401` `isSponsoredDisabled()` | 返回 `!userFull.sponsored_enabled`（服务端开关，Premium 用户可关） |

**结论**：官方本就有"Premium 用户可关广告"的开关，但被 `isPremium()` 前置条件挡住。
最干净的补丁 = 让 `addSponsoredMessages` 直接返回，从而**连网络请求都不会发**。

### 2.2 搜索页 sponsored peer（推荐频道）

| 位置 | 作用 |
|---|---|
| `DialogsSearchAdapter.java:1134-1137` | 发 `contacts.getSponsoredPeers` 请求 |
| `DialogsActivity.java:13283` | 点击 `TL_sponsoredPeer` 的处理 |

### 2.3 其它可能含广告的位置（待评估）

| 位置 | 说明 |
|---|---|
| `messenger/video/VideoAds.java:198` | 视频播放前的广告，同样被 `isPremium() && isSponsoredDisabled()` 门控 |
| `ui/bots/BotAdView.java` | Bot 内广告 |
| `ui/ChannelMonetizationLayout.java` | 频道变现相关 |
| `ui/PremiumPreviewFragment.java` | Premium 推广页（属"推广"非"广告"，待确认是否要动） |

---

## 三、补丁设计草案

### G1-a 扫码登录（新写）

```
LoginActivity 新增 VIEW_QR / 或复用 page 机制：
  1. 进入登录页 QR 模式 → 调 TL_auth_exportLoginToken(api_id, api_hash, [])
  2. 返回 TL_auth_loginToken { token, expires } → base64url → "tg://login?token=..."
     → TelegramQRCodeWriter 渲染二维码 + 提供"复制链接"按钮（兼容无扫码能力的旧设备）
  3. 定时（约每 2s，且持续到 expires）重新 exportLoginToken 轮询：
     - TL_auth_loginToken      → 继续轮询
     - TL_auth_loginTokenMigrateTo → 切 DC 后重新 export
     - TL_auth_loginTokenSuccess   → 登录成功，进入主界面
  4. 若账号开启 2FA → 进入云密码页（复用现有流程）
```

### G2 去广告（最小改动）

```java
// ChatActivity.addSponsoredMessages 首行
private void addSponsoredMessages(boolean animated) {
    return;  // [patch] 移除频道内赞助消息
    ...
}

// DialogsSearchAdapter 请求 sponsored peers 处
// 直接不发起 contacts.getSponsoredPeers
```

**回滚粒度**：两处各一个 commit，互不耦合。

---

## 四、对 SPEC 的影响（需出 v2.2）

| 项 | v2.1 表述 | 修正 |
|---|---|---|
| `allow_app_hash` 语义 | 「允许通过 Telegram App 接收验证码」 | ❌ 错误。实为 Android SMS Retriever 的 app hash，与投递通道无关 |
| G1 主通道 | 扫码（已验证）+ 邮箱 | 不变，但理由更新：扫码=唯一可控通道；邮箱=官方已实现白送；App 内验证码=不可强制 |
| AC-1b | 「`app_hash` 模式返回 `SentCodeTypeApp`」 | 作废——该假设基于错误语义 |
