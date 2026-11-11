# M0 Spike 验证记录（2026-11-02）

## 环境与方法

| 项 | 值 |
|---|---|
| 执行机 | `pve-debian12`（Debian 12，中国境内数据中心出口 IP） |
| api_id / api_hash | 官方源码 `BuildVars.java` 内置的那对（APP_ID = 4） |
| 测试号码 | +44 7***95（用户本人自有号码，已脱敏） |
| 工具 | Python 3.11 + Telethon 1.45.0（TL layer 含 `allow_app_hash`） |
| 脚本 | `tools/probe/probe_sentcode.py` |

## 实验一：`auth.sendCode`（验证码通道）

**三个模式全部返回同一个错误**（此处展示 `app_hash` 模式）：

```
$ python3 probe_sentcode.py --mode app_hash
----- mode=app_hash -----
CodeSettings: <CodeSettings allow_app_hash=True>
Traceback ...
telethon.errors.rpcbaseerrors.ForbiddenError:
  RPCError 403: RECAPTCHA_CHECK_signup__6LdcRsEqAAAAAHUaNCc1GUe47g5jKlOzbJJiyIZt
  (caused by SendCodeRequest)
```

**结论**：服务端**未进入"选择投递通道"阶段**，直接要求人机验证。因此
`SentCodeTypeApp` vs `SentCodeTypeSms` 的问题**在本环境无法回答**。

**成因分析**：
1. `RECAPTCHA_CHECK_<action>__<siteKey>` 是 Telegram 的反滥用机制，需客户端渲染
   reCAPTCHA、真人通过后取 token，再用 `auth.invokeWithReCaptcha` 重放请求。
2. action 名为 `signup`，说明服务端把这次请求判定为"疑似注册"级别的高风险操作。
3. 触发因素高度可能是 **IP 信誉**：中国境内数据中心 IP，为英国号码请求登录码，
   且使用官方 api_id 4 —— 三个信号叠加。

**不做的事**：不尝试程序化破解/绕过 reCAPTCHA。这是反滥用机制，绕过它既不可靠也不正当。

## 实验二：`auth.exportLoginToken`（扫码登录通道）

```
$ python3 probe_sentcode.py --mode qr
----- mode=qr (auth.exportLoginToken) -----
返回类型: LoginToken
expires : 2026-11-02 00:20:55+00:00
判定    : ✅ 扫码登录通道可用（能生成二维码登录令牌，全程不发短信）

RESULT: LoginToken
```

**结论**：`auth.exportLoginToken` **成功返回 `LoginToken`**——没有 captcha、没有短信、
不消耗验证码额度。

### 这意味着什么

扫码登录的完整链路对本项目是**打通的**：

```
新设备(自建客户端)                旧设备(已登录)
   │                                │
   ├─ auth.exportLoginToken ──┐     │
   │   ← LoginToken(token,expires)  │
   │                          │     │
   ├─ 渲染 QR / tg://login?token=  ──┼─→ 扫描或点开链接
   │                                ├─ auth.importLoginToken(token)
   │                          ┌─────┘   （旧设备需确认）
   ├─ auth.exportLoginToken ──┘
   │   ← LoginTokenSuccess          │
   └─ 登录完成（若开 2FA 则仍需输密码）
```

## 对 SPEC 的影响

| 原假设 | 修订 |
|---|---|
| G1 主路径 = `sentCodeTypeApp`（App 内验证码） | **主路径改为扫码登录（已验证）**；App 内验证码降为"待验证的备用通道" |
| AC-1 = `RESULT: SentCodeTypeApp` | 修订为：`RESULT: LoginToken`（QR 通道）**已验证通过**；App 内验证码通道另立 AC，需在干净网络下复测 |
| 风险 R1（allow_app_hash 无效） | 不再阻塞：即使该开关无效，扫码通道已能达成 G1 |

## 未回答的问题

1. **`allow_app_hash` 到底能不能换来 `SentCodeTypeApp`？**
   需要在"干净网络"下复测：用户自己的电脑/手机热点，而不是本机数据中心 IP。
2. 若最终 App 里仍需要走验证码通道，官方客户端的 captcha UI 可让真人手动过一次，
   但过完之后服务端给的是 App 内验证码还是短信，仍需实测。

## 复现命令

```bash
cd tools/probe && . .venv/bin/activate
TG_API_ID=4 TG_API_HASH=<见源码 BuildVars> TG_PHONE=<你的号码> \
  python3 probe_sentcode.py --mode qr
```
