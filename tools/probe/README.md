# Telegram API 探针脚本（M0 / 扫码通道验证）

本目录包含两个**只读/最小副作用**的 Telethon 探针，用于在不改 Android 代码的前提下验证 Telegram 登录协议行为：

| 脚本 | 目的 | 结论（2026-11-02） |
|---|---|---|
| `probe_sentcode.py` | 用**自有 api_id** 调 `auth.sendCode`，观察验证码走 App 内 / 邮箱 / 短信 | 本机网络被 reCAPTCHA 拦截，未完成；结论不影响扫码方案 |
| `probe_qr_poll.py` | 连续调 `auth.exportLoginToken`，观察 token 是否变化、TTL 多长 | 30s TTL 内多次 export 返回同一 token → 客户端可每 2s 轮询且不必每次重绘二维码（见 `docs/evidence/qr-token-poll-probe.md`） |

## 前置条件

1. 一台仍登录着目标账号的设备（用于在需要时接收/确认验证码；扫码探针不需要登录）；
2. `probe_sentcode.py` 需要你自己的 `api_id` / `api_hash`（在 https://my.telegram.org → API development tools 申请）。

## 运行

```bash
cd <repo-root>/tools/probe

# 1) 虚拟环境（Debian/Ubuntu 的系统 pip 受 PEP 668 保护）
python3 -m venv .venv
. .venv/bin/activate
pip install -U telethon

# 2) 验证码通道探针（需要自有 api_id；手机号带 + 和国家码）
export TG_API_ID=你的api_id
export TG_API_HASH=你的api_hash
export TG_PHONE=+8613800000000
python3 probe_sentcode.py

# 3) 二维码 token 轮询探针（无需登录，使用上游公开测试 id）
python3 probe_qr_poll.py
```

## 结果判读

| RESULT | 含义 | 下一步 |
|---|---|---|
| `SentCodeTypeApp` | 自有 api_id 能拿到 App 内通道 | 可走「自有 api_id」方案 |
| `SentCodeTypeEmailCode` | 走登录邮箱 | 需账号已绑定登录邮箱 |
| `SentCodeTypeSms` | 仍走短信 | 可能产生费用 |
| `SentCodeTypeFragmentSms` | 触发付费验证 | 该网络/号码风险较高 |

## 安全边界（重要）

- 两个脚本**不调用 `sign_in`**、不发送消息、不修改账号数据；唯一副作用是可能产生一条登录验证码（不输入即作废）。
- `probe_qr_poll.py` 使用上游公开的测试 `api_id = 4`（与官方源码一致），仅做只读协议探测。
- **`.session` 文件等价于登录态凭据，已被 `.gitignore` 排除，永远不要提交、不要粘贴到 issue/聊天**。
  `.venv/` 与 `__pycache__/` 同样不纳入版本库。
- 脚本打印的 phone/hash 均已脱敏。
