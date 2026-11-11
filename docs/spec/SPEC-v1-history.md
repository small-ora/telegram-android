# 需求规格说明书（SPEC v1）

> 项目代号：`tg-self-client`
> 版本：**v1.0 — 待确认**
> 日期：2026-11-01
> 分级：**L3**（涉及登录鉴权链路 → 红线；按 `ai-dev-workflow` 要求，SPEC 需人确认后方可进入实现）
> 状态：⬜ 待你确认　⬜ 待冻结（确认后落为 SPEC_BASE）

---

## 1. 背景与问题

### 1.1 现象

在中国大陆手机号（+86）于**官方 Telegram 客户端**登录新设备时，界面弹出 **SMS Fee（短信费用）** 页面，内容为：

> 短信费用高昂。您所在国家/地区的电信运营商向 Telegram 收取非常高的短信费用。需要验证：Telegram 需要向您发送一条包含验证码的短信以确认您的手机号码。
> **通过 Telegram Premium 获得支持 —— 注册为期一周的 Telegram Premium 会员，即可帮助支付短信费用。**

即：登录并非被会员功能锁住，而是**这唯一一条通道（短信）被计费**；不付费就拿不到验证码，登录无法完成。

### 1.2 已知事实（已查证）

| 事实 | 依据 |
|---|---|
| 该页面是 `SMS Fee` 反滥用计费，非会员功能限制 | [实测案例](https://www.shuijingwanwq.com/2026/03/02/9330/) |
| Telegram 官方 API 支持把验证码送进**已登录会话**：`auth.sentCodeTypeApp`（"The code was sent through the telegram app"） | [TDLib 认证流程](https://deepwiki.com/tdlib/td/2.4-authentication-flow)、[auth.sentCodeTypeApp](https://docs.pyrogram.org/telegram/types/auth/sent-code-type-app) |
| 支持发往**预先绑定的登录邮箱**：`auth.sentCodeTypeEmailCode` | [auth.sentCodeTypeEmailCode](https://docs.madelineproto.xyz/API_docs/constructors/auth.sentCodeTypeEmailCode.html) |
| 支持**扫码登录**：`auth.exportLoginToken` / `auth.importLoginToken` | [Method: auth.exportLoginToken](https://github.com/danog/madelineprotodocs/blob/2036a92808f613c48bfb5fb7f0c93324fbaf301f/docs/API_docs/methods/auth.exportLoginToken.md) |
| 支持**另一设备确认登录**：`AuthorizationStateWaitOtherDeviceConfirmation` | TDLib 认证状态机 |
| 同一场景下第三方客户端（Nagram）登录时**不弹费用**，而是提示"请到另一台已登录设备查看验证码" | [实测案例 第 17 条](https://www.shuijingwanwq.com/2026/03/02/9330/) |
| 官方 Android 客户端源码开放：`DrKLO/Telegram`，License GPLv2 | [GitHub](https://github.com/DrKLO/Telegram) |

### 1.3 推论

第三方客户端之所以能走通，是因为 TDLib 的 `auth.sendCode` 请求携带**"允许通过 Telegram App 接收验证码"的开关**（历史字段名 `allow_app_hash`，语义为代码可经 App 内通道送达），配合账号上已存在的登录会话，服务端即返回 `sentCodeTypeApp` 而非短信。

**这是 Telegram 官方 API 提供的正式能力，不是绕过安全机制。** 2FA 密码该输仍需输入。

---

## 2. 目标与非目标

### 2.1 目标

| ID | 目标 |
|---|---|
| **G1** | 在新设备上用 +86 手机号完成登录，**全程不触发 SMS Fee、不付费、不收短信** |
| **G2** | 登录验证码优先通过"已登录会话内的 App 内验证码"送达；邮件与扫码作为备用通道 |
| **G3** | 登录成功后客户端功能完整可用（保留官方客户端的全部功能，最小改动原则） |
| **G4** | 产出一个可自行 sideload 的 APK，构建过程可复现 |

### 2.2 非目标（明确不做）

| ID | 非目标 | 理由 |
|---|---|---|
| N1 | 不自行实现 MTProto 协议 | 用官方 TDLib，自研协议不可行且高风险 |
| N2 | 不重做 UI / 不换设计语言 | 最小改动原则，保留官方界面 |
| N3 | 不做多账号管理、不做通话、不做自定义主题 | 官方已具备，无需新增 |
| N4 | **不绕过两步验证（2FA）** | 不属于本次问题范围，也不应绕过 |
| N5 | 不发布到任何应用商店、不分发给他人 | 仅自用，规避 GPL 分发义务与 ToS 风险 |
| N6 | 不逆向、不篡改官方签名、不复用官方发布包 | 只用公开源码自行编译 |
| N7 | 不修改任何服务端行为、不代理/中继 Telegram 流量 | 纯客户端侧改动 |

---

## 3. 用户与使用场景

**用户**：你本人，单一账号，单人使用。技术上会编程但无安卓开发经验。

**设备环境**：
- 旧设备：已登录的第三方客户端（Telegram X / Nagram），保持登录状态
- 新设备：待登录的 Android 手机，安装本项目自建的 APK

**场景**：

| ID | 场景 | 期望 |
|---|---|---|
| S1 | 新设备首次登录 | 输手机号 → 选"App 内验证码" → 旧设备收到 5 位码 → 输入 → 登录成功 |
| S2 | 账号开启了 2FA | 在 S1 之后正常要求输入两步验证密码 |
| S3 | 旧设备不在手边 | 通过**登录邮箱**接收验证码完成登录 |
| S4 | 旧设备在手上 | 直接**扫码**登录，连验证码都不用输 |
| S5 | 会话被踢 / 重装应用 | 重复 S1，行为一致 |

---

## 4. 功能需求

| ID | 需求 | 优先级 |
|---|---|---|
| **FR-1** | 登录页必须提供三种验证码通道的明确入口：①App 内验证码 ②登录邮箱 ③扫码登录 | P0 |
| **FR-2** | `auth.sendCode` 必须携带"允许 App 内接收"的设置，使服务端倾向返回 `sentCodeTypeApp` | P0 |
| **FR-3** | 当服务端实际返回的是 `sentCodeTypeApp` 时，UI 明确提示"验证码已发送到你已登录的设备"，而不是提示等待短信 | P0 |
| **FR-4** | 当返回 `sentCodeTypeEmailCode` 时，展示脱敏邮箱（如 `a***@qq.com`）并允许输入 | P1 |
| **FR-5** | 支持扫码登录：展示二维码，供旧设备"设置 → 设备 → 关联桌面设备"扫描确认 | P1 |
| **FR-6** | 遇到 `sentCodeTypeSms` / `sentCodeTypeFragmentSms`（即会触发费用）时，**拦截并提示改用其他通道**，不引导付费 | P0 |
| **FR-7** | 2FA 密码流程保持官方原有行为，不做任何改动 | P0 |
| **FR-8** | 登录成功后，官方原有功能全部保留且可用（最小改动原则） | P0 |
| **FR-9** | `api_id` / `api_hash` 从本地未纳入版本控制的配置读取，不硬编码进仓库 | P0 |

---

## 5. 验收标准（AC）

> 每条均可观察、可复现。证据格式：命令 + 退出码 + 关键输出（脱敏）。

| ID | 验收标准 | 验证方式 |
|---|---|---|
| **AC-1** | 使用**自有 api_id** 请求验证码，服务端返回类型为 `SentCodeTypeApp` 或 `SentCodeTypeEmailCode`，而非 `Sms`/`FragmentSms` | 运行 `tools/probe/probe_sentcode.py`，输出 `RESULT: SentCodeTypeApp` 等 |
| **AC-2** | 新设备安装 APK，输入 +86 手机号后**不出现 SMS Fee 页面**，且旧设备会话内 3 分钟内收到 "Login code: XXXXX" 消息 | 真机操作 + 旧设备截图 |
| **AC-3** | 输入该验证码后成功进入会话列表，可正常收发消息 | 真机操作，发一条消息并收到回复 |
| **AC-4** | 登录页提供扫码入口，旧设备扫码后新设备直接登录成功（无需验证码） | 真机操作 |
| **AC-5** | 账号若已绑定登录邮箱，可选择邮箱通道并收到验证码 | 真机操作（可选，若无邮箱绑定则跳过并记录） |
| **AC-6** | 账号若开启 2FA，登录流程正常要求并校验密码 | 真机操作 |
| **AC-7** | 官方原有功能抽查无回归：会话列表、发消息、收消息、设置页、通知 | 真机操作清单 |
| **AC-8** | 构建可复现：给出确定命令产出 arm64-v8a APK，并记录 JDK/NDK/Gradle 版本 | `./gradlew assembleRelease` 退出码 0 + 产物路径 + 版本清单 |

---

## 6. 技术方案

### 6.1 基座

**fork 官方 [`DrKLO/Telegram`](https://github.com/DrKLO/Telegram)（GPLv2）**，最小改动。

| 备选 | 未选原因 |
|---|---|
| Nekogram / Nagram / Cherrygram | 有报道称部分 fork 向开发者回传账号与号码，自建客户端不应引入未知外发 |
| Telegram X | 全 C++/原生，改造门槛过高 |
| 从零 Kotlin + Compose + TDLib | C 档功能需数月，与"最小改动"矛盾 |

### 6.2 api_id 策略（**关键决策，待 Spike 结果**）

| 方案 | 做法 | 合规性 | 风险 |
|---|---|---|---|
| **A（优先）** | 用你自己在 my.telegram.org 注册的 api_id/api_hash | ✅ 符合 Telegram API 条款 | 若服务端仍判给短信，则方案不可行 |
| **B（兜底）** | 沿用官方源码内置的 api_id `4` | ⚠️ 属于使用他人 api_id，违反条款 | 可能被风控；理论上存在账号风险；现实中现存第三方客户端普遍如此 |

**决策规则**：Spike 若证明方案 A 能拿到 App/Email 通道 → 采用 A；若只能拿到 SMS → 停下来由你决定是否接受方案 B 的风险。

### 6.3 预期改动点（待源码勘察后细化）

| 文件/模块 | 改动 |
|---|---|
| `TMessagesProj/src/main/java/org/telegram/messenger/BuildVars.java` | api_id/api_hash 改为从本地配置读取 |
| `LoginActivity` / 登录相关 Fragment | `sendCode` 参数加 App 内接收开关；按 `sentCodeType` 分支渲染提示 |
| 登录页 UI | 增加"扫码登录"入口；SMS Fee 类型的拦截提示 |
| 文案资源 | 新增中文提示文案 |

### 6.4 构建产物

- `arm64-v8a` Release APK（按你的真机 ABI）
- 签名为本地自签名（自用，无需上架）

---

## 7. 风险登记

| ID | 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|---|
| **R1** | 自有 api_id 仍被判定走短信通道 → 方案 A 失败 | 中 | 高（被迫选 B） | **Spike 先验证（AC-1）**，成本仅半天 |
| **R2** | 用官方 api_id 触发风控/账号风险 | 低-中 | 高 | 优先方案 A；方案 B 需你明确接受 |
| **R3** | 官方源码首次构建失败（NDK/依赖/版本不匹配） | **高** | 中（耗时） | 严格按官方 README 工具链版本；分步验证 |
| **R4** | 内存/磁盘不足导致构建 OOM | 中 | 中 | 限制 Gradle 堆、清缓存、必要时加 swap |
| **R5** | 源码体积巨大、编译慢（单次 10–30 分钟） | 高 | 低 | 增量编译，减少全量重建 |
| **R6** | Telegram 服务端行为变更，通道失效 | 中 | 高 | 保留邮箱 + 扫码两条独立备用通道 |
| **R7** | GPLv2 义务 | 低 | 低 | 仅自用不分发，不触发分发义务 |
| **R8** | 旧设备（第三方客户端）会话若被踢，App 内验证码通道失效 | 低 | 高 | 提前绑定登录邮箱作为独立备用 |

---

## 8. 合规与安全边界

1. **仅限你自己的账号**。本方案的一切能力建立在"你已拥有一个已登录会话"之上；不涉及、不协助任何他人账号。
2. **不绕过 2FA**。两步验证密码按官方流程正常校验。
3. **不使用、不索取他人的 api_id**。方案 A 全程使用你自己注册的凭据。
4. **不引入来源不明的二进制**。基座只用官方公开源码，依赖走官方 Maven/Gradle。
5. **凭据不入库**。`api_id`/`api_hash` 仅存本地，加入 `.gitignore`，文档与日志一律脱敏。
6. **不分发**。构建产物仅 sideload 到你自己设备。

---

## 9. 里程碑

| 里程碑 | 内容 | 预估 | 前置 |
|---|---|---|---|
| **M0** | Spike：探测自有 api_id 的验证码类型 | 0.5 天 | ⛔ 需你提供 api_id/api_hash |
| **M1** | 装工具链 + 拉取源码 + 首次编译通过 | 2–3 天 | M0 结论 |
| **M2** | 登录通道改造（FR-1~FR-6、FR-9） | 2 天 | M1 |
| **M3** | 构建 APK + 真机验证（AC-2~AC-7） | 1 天 | M2 |
| **M4** | 自检 + 独立审查 + 验收包 | 0.5 天 | M3 |

---

## 10. 待你确认的问题（Blocking）

| ID | 问题 | 需要你做什么 |
|---|---|---|
| **Q1** | 请提供 `api_id` / `api_hash` | 在旧设备保持登录的状态下访问 https://my.telegram.org → API development tools → 创建应用，把两个值发我（或你自己跑 Spike 脚本后贴结果） |
| **Q2** | 若 Spike 证明自有 api_id 只能触发短信（方案 A 失败），是否接受方案 B（沿用官方 api_id 4，违反条款、有风控风险）？ | 明确回答"接受 / 不接受，另寻方案" |
| **Q3** | 目标手机的 CPU 架构与 Android 版本 | 手机设置里查看，或告诉我机型 |
| **Q4** | 代码目录放在哪？ | 建议与文档同级：`<repo-root>`（GPL 源码体积大，建议独立目录） |
| **Q5** | 是否同意采用本 SPEC 作为开发基线（冻结）？ | 回复"同意"，我即进入 M0 |

---

## 11. 附：本 SPEC 的变更规则

- 确认后冻结为 **SPEC_BASE（v1.0）**。实现阶段如需改动 AC，必须出新版本并说明 `old → new`，由你确认。
- 本规格不含任何真实凭据。
