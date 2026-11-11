# 需求规格说明书（SPEC v2）

> 项目代号：`tg-self-client`
> 版本：**v2.1**（v2.0 → v2.1：M0 Spike 完成，扫码通道实测可用，AC-1 据此修订）
> 日期：2026-11-02
> 分级：**L3**（涉及登录鉴权链路 → 红线）
> 状态：⬜ 待体检证（Spike）　⬜ 待你确认后冻结

---

## 0. v1 → v2 变更摘要

| 项 | v1 | v2 |
|---|---|---|
| 需求范围 | C 档准完整客户端（自研大量功能） | **只改 2 个点**，其余全部沿用官方功能 |
| api_id 策略 | 待 Spike 决定方案 A / B | **已定：直接用官方源码内置的 api_id 4**（用户明示接受条款与风控风险） |
| 非目标 | 含 UI 改造等 | 明确：除 2 个点外，**一切保持官方原样** |

---

## 1. 背景

+86 手机号在官方客户端登录时弹出 **SMS Fee（短信费用）**，要求购买 Telegram Premium 才能支付短信费。这是 Telegram 针对高成本短信地区的反滥用计费，不是会员功能限制。

同时官方客户端在频道内和会话列表中存在 **sponsored（广告/推荐）内容**。

用户对官方客户端的不满意**仅此两点**，其余功能全部满意。

---

## 2. 目标（仅 2 条）

| ID | 目标 | 一句话 |
|---|---|---|
| **G1** | **登录不走短信验证码** | 新设备登录时，验证码通过「已登录会话内的 App 验证码」或「登录邮箱」或「扫码」完成，全程不触发 SMS Fee |
| **G2** | **去除应用内广告** | 去掉频道内 sponsored messages 与会话列表的 sponsored peer（推荐频道），不改变其他任何行为 |

### 非目标

| ID | 非目标 |
|---|---|
| N1 | 不重做 UI、不换设计、不改包名图标（除非后续你提） |
| N2 | **不绕过两步验证（2FA）**——2FA 照常校验 |
| N3 | 不做任何官方已有功能的新增或删减（除 G1、G2 的副作用外） |
| N4 | 不自行实现 MTProto 协议（用官方 TDLib） |
| N5 | 不发布、不分发给他人，仅自用 sideload |
| N6 | 不逆向官方发布包、不复用官方签名 |
| N7 | 不代理/中继 Telegram 流量 |

---

## 3. 关键技术决策

### 3.1 基座

fork 官方 [`DrKLO/Telegram`](https://github.com/DrKLO/Telegram)（GPLv2），最小改动。

### 3.2 api_id（已决策）

采用官方源码 `BuildVars.java` 中内置的：

```java
public static int APP_ID = 4;
public static String APP_HASH = "014b35...";   // 见源码第 30 行
```

**已确认风险（用户明示接受）**：
- 违反 Telegram API 条款（条款要求使用自己申请的 api_id）
- 存在账号被标记/风控的理论风险
- 4 号 api_id 为全球共享，部分接口可能更易触发限流

**工程约束**：仍然把 `APP_ID` / `APP_HASH` 提取到构建配置（`local.properties` 或 `gradle.properties`，不入库），以便日后切换为自己的 api_id 时无需改代码。

### 3.3 登录通道的技术立足点

TDLib/TL 层 `CodeSettings` 含 `allow_app_hash` 开关；配合账号上已有的活跃会话，服务端可返回 `SentCodeTypeApp`（验证码作为服务消息送达所有已登录会话），而非短信。

**当前正在验证**（Spike，见 §6），实验设计：

| 模式 | CodeSettings | 对照意义 |
|---|---|---|
| `bare` | `{}` 空设置 | Telethon 默认行为，对照组 |
| `app_hash` | `allow_app_hash=True` | 请求 App 内通道 ★ |
| `current` | `allow_app_hash + current_number` | 变体 |

判定组合：
- `app_hash` = `SentCodeTypeApp` → ✅ 方案成立，按此实现
- `app_hash` = `Sms/FragmentSms` 但 `bare` = `App` → 开关取值反了，调整
- 两者都是 `Sms/FragmentSms` → 该号码/该 api_id 无法走 App 通道，需重新讨论（可能转向：登录邮箱 or 扫码 or 其他 api_id）

### 3.4 实测结果（2026-11-02，详见 `evidence/M0-spike-result.md`）

| 实验 | 结果 | 含义 |
|---|---|---|
| `auth.sendCode`（`bare` / `app_hash` / `current`） | ❌ **被 reCAPTCHA 拦截**：`403 RECAPTCHA_CHECK_signup__<sitekey>` | 服务端未进入通道选择阶段。成因判断为**数据中心 IP + 境外号码 + 官方 api_id** 三重信号触发的反滥用。不绕过。 |
| **`auth.exportLoginToken`（扫码）** | ✅ **返回 `LoginToken`** | 扫码登录链路完全可用，不发短信、不消耗验证码额度、无 captcha |

**因此 G1 的主路径调整为「扫码登录」**（已验证），「App 内验证码」降级为备用通道（待干净网络下复测）。

---

## 4. 验收标准（AC）

| ID | 验收标准 | 验证方式 |
|---|---|---|
| **AC-1** | 扫码通道可用：`auth.exportLoginToken` 返回 `LoginToken` | ✅ **已验证通过**（2026-11-02，`RESULT: LoginToken`） |
| **AC-1b** | App 内验证码通道：`app_hash` 模式下返回 `SentCodeTypeApp` | ⏸ 待测：本机数据中心 IP 触发 reCAPTCHA 拦截，需在干净网络下复测 |
| **AC-2** | 新设备安装 APK，输入 +86 号码后**不出现 SMS Fee 页面**，且旧设备会话内 3 分钟内收到 `Login code: XXXXX` | 真机 + 旧设备截图 |
| **AC-3** | 输入验证码后成功登录并进入会话列表 | 真机 |
| **AC-4** | 若开启 2FA，登录流程正常要求并校验密码 | 真机 |
| **AC-5** | 频道内**不再出现 sponsored message**（找带广告的频道滚动验证） | 真机 + 前后对比截图 |
| **AC-6** | 会话列表**不再出现 sponsored peer（推荐频道）** | 真机 + 前后对比截图 |
| **AC-7** | 官方其余功能无回归（抽查：收发消息、图片视频、语音、设置、通知、搜索、群组、频道订阅） | 真机清单逐项打勾 |
| **AC-8** | 构建可复现：一条命令产出 arm64-v8a APK，记录 JDK/NDK/Gradle 版本 | `./gradlew assembleRelease` 退出码 0 + 版本清单 |

---

## 5. 预期改动点（待源码勘察确认）

### G1 登录通道

| 位置 | 改动 |
|---|---|
| `TMessagesProj/.../BuildVars.java` | api_id/hash 改从构建配置读取 |
| 登录相关 Activity/Fragment（`LoginActivity` 等） | `sendCode` 携带 `CodeSettings(allow_app_hash=true)` |
| 登录页 UI 文案 | 按返回的 `sentCodeType` 分支渲染：App / Email / 扫码；**拦截 SMS/Fee 分支并提示改用其他通道** |
| 二维码登录入口 | 确认官方源码是否已具备，若具备则只需调整入口可见性 |

### G2 去广告

| 位置 | 改动 | 说明 |
|---|---|---|
| 频道内 sponsored messages 的拉取与渲染 | 请求侧直接跳过 + 渲染侧短路 | 官方源码中 `MessagesController` 的 sponsored 相关方法，**具体方法名待勘察** |
| 会话列表 sponsored peer | 渲染侧短路 | 同上 |

> 具体类名/方法名以实际拉取到的源码为准，勘察后补充到本节。

---

## 6. 里程碑

| 里程碑 | 内容 | 依赖 |
|---|---|---|
| **M0 Spike** | 探针结论 | ✅ **已完成（2026-11-02）**：QR 通道可用；验证码通道被 captcha 拦截，待干净网络复测 |
| **M1 环境** | JDK17 + SDK + NDK + 首次编译通过 | M0 结论 |
| **M2 G1 改造** | 登录通道 | M1 |
| **M3 G2 改造** | 去广告 | M2 |
| **M4 验证** | 构建 APK + 真机验证 AC-2~AC-7 | M3 |

---

## 7. 风险

| ID | 风险 | 缓解 |
|---|---|---|
| R1 | `allow_app_hash` 不改变服务端投递通道（号码级策略） | M0 直接验证；失败则转向邮箱/扫码 |
| R2 | api_id 4 被封/限流 | 配置化，随时可换自有 api_id |
| R3 | 官方源码首次编译失败（NDK/依赖） | 按官方 README 工具链版本；分步验证 |
| R4 | 去广告改动波及消息刷新逻辑导致异常 | 只做渲染短路 + 请求短路，不动消息管线；真机回归 AC-7 |
| R5 | 内存/磁盘不足 | 限制 Gradle 堆、清缓存 |

---

## 8. 待确认

| ID | 事项 |
|---|---|
| Q1 | 提供手机号（+86...）以完成 M0 Spike —— **仅用于发起一次验证码请求** |
| Q2 | 确认本 v2 规格（同意后冻结为 SPEC_BASE v2，进入 M1） |
