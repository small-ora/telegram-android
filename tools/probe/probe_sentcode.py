#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Spike 探针 v2：探测 Telegram 服务端把登录验证码投递到哪条通道。

对应 SPEC AC-1。

核心实验：同一手机号、同一 api_id，**改变 CodeSettings 开关**，观察返回的 SentCodeType 是否变化。
    --mode app_hash   : allow_app_hash=True（请求"通过 App 内接收验证码"）★ 默认
    --mode current    : allow_app_hash=True + current_number=True
    --mode bare       : 空 CodeSettings（Telethon 的默认行为，作为对照组）
    --mode all        : 依次跑 bare / app_hash（两次请求，注意额度）

用法：
    export TG_API_ID=4
    export TG_API_HASH=014b35b6184100b085b0d0572f9b5103
    export TG_PHONE=+86xxxxxxxxxxx
    python3 probe_sentcode.py                 # 默认 app_hash
    python3 probe_sentcode.py --mode bare     # 对照组

安全边界：
  * 只调用 auth.sendCode，**从不调用 auth.signIn**，不写任何账号数据
  * 唯一副作用：产生一条登录验证码（不输入即作废），并消耗该号码的一次当日认证额度
  * 输出自动脱敏手机号与 phone_code_hash
"""

import argparse
import os
import sys


def mask_phone(p: str) -> str:
    digits = "".join(ch for ch in p if ch.isdigit())
    if len(digits) <= 5:
        return "*" * len(digits)
    return f"+{digits[:3]}****{digits[-2:]}"


def build_settings(mode: str):
    from telethon.tl import types
    if mode == "bare":
        return types.CodeSettings()
    if mode == "app_hash":
        return types.CodeSettings(allow_app_hash=True)
    if mode == "current":
        return types.CodeSettings(allow_app_hash=True, current_number=True)
    raise ValueError(f"未知 mode: {mode}")


def describe(sent) -> str:
    t = sent.type
    name = type(t).__name__
    detail = []
    pattern = getattr(t, "email_pattern", None)
    if pattern:
        detail.append(f"email_pattern={pattern}")
    length = getattr(t, "length", None)
    if length:
        detail.append(f"code_length={length}")
    url = getattr(t, "url", None)
    if url:
        detail.append(f"url={url}")
    if sent.next_type is not None:
        detail.append(f"next_type={type(sent.next_type).__name__}")
    return name + (("  [" + ", ".join(detail) + "]") if detail else "")


VERDICT = {
    "SentCodeTypeApp":         "✅ App 内通道——验证码会出现在已登录会话里（目标达成）",
    "SentCodeTypeEmailCode":   "✅ 登录邮箱通道（可用，需事先绑定登录邮箱）",
    "SentCodeTypeSms":         "❌ 短信通道（会触发 SMS Fee）",
    "SentCodeTypeFragmentSms": "❌ 付费通道（Fragment）",
    "SentCodeTypeFlashCall":   "⚠️ 闪呼通道",
    "SentCodeTypeCall":        "⚠️ 语音通道",
    "SentCodeTypeMissedCall":  "⚠️ 未接来电通道",
    "SentCodeTypeFirebaseSms": "⚠️ Firebase 短信通道",
}


def run_one(client, mode: str, phone: str) -> str:
    """执行一次 auth.sendCode，返回 SentCodeType 类名。"""
    from telethon import functions, errors

    settings = build_settings(mode)
    print(f"\n----- mode={mode} -----")
    print(f"CodeSettings: {settings!r}")

    try:
        result = client(functions.auth.SendCodeRequest(
            phone, client.api_id, client.api_hash, settings))
    except errors.FloodWaitError as e:
        print(f"⛔ FLOOD_WAIT: 需等待 {e.seconds}s（约 {e.seconds/3600:.1f}h）")
        return f"FLOOD_WAIT:{e.seconds}"
    except errors.PhoneNumberInvalidError:
        print("⛔ PHONE_NUMBER_INVALID: 号码格式无效（沙盒验证时属预期）")
        return "PHONE_NUMBER_INVALID"

    # 如果这个 session 已经登录，sendCode 会返回 SentCodeSuccess
    if type(result).__name__ == "SentCodeSuccess":
        print("ℹ️ SentCodeSuccess：该 session 已登录，不再需要验证码")
        return "ALREADY_AUTHORIZED"

    desc = describe(result)
    print(f"SentCodeType : {desc}")
    print(f"判定         : {VERDICT.get(type(result.type).__name__, '❓ 未知类型')}")
    if result.phone_code_hash:
        h = result.phone_code_hash
        print(f"phone_code_hash: {h[:6]}...{h[-4:]} (已脱敏)")
    if result.timeout:
        print(f"timeout      : {result.timeout}s")
    return type(result.type).__name__


def run_qr(client) -> str:
    """探测扫码登录通道：auth.exportLoginToken。不发短信、不消耗验证码额度。"""
    from telethon import errors
    from telethon.tl.functions.auth import ExportLoginTokenRequest

    print("\n----- mode=qr (auth.exportLoginToken) -----")
    try:
        res = client(ExportLoginTokenRequest(client.api_id, client.api_hash, []))
    except errors.FloodWaitError as e:
        print(f"⛔ FLOOD_WAIT: 需等待 {e.seconds}s")
        return f"FLOOD_WAIT:{e.seconds}"
    except errors.RPCError as e:
        print(f"⛔ RPC 错误: {e.__class__.__name__}: {e}")
        return f"RPC_ERROR:{e.__class__.__name__}"

    name = type(res).__name__
    print(f"返回类型: {name}")
    if name == "LoginToken":
        # token 是登录凭据，不打印
        print(f"expires : {getattr(res, 'expires', '?')}")
        print("判定    : ✅ 扫码登录通道可用（能生成二维码登录令牌，全程不发短信）")
    elif name == "LoginTokenMigrateTo":
        print(f"判定    : ⚠️ 需要迁移到 DC{getattr(res, 'dc_id', '?')} 后重新申请")
    elif name == "LoginTokenSuccess":
        print("判定    : ℹ️ 该会话已授权")
    else:
        print("判定    : ❓ 未知返回类型")
    return name


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", default="app_hash",
                    choices=["app_hash", "current", "bare", "all", "qr"])
    args = ap.parse_args()

    api_id = os.environ.get("TG_API_ID", "").strip()
    api_hash = os.environ.get("TG_API_HASH", "").strip()
    phone = "".join(os.environ.get("TG_PHONE", "").split())

    if not (api_id and api_hash and phone):
        print("ERROR: 需要环境变量 TG_API_ID / TG_API_HASH / TG_PHONE", file=sys.stderr)
        return 2
    try:
        api_id_int = int(api_id)
    except ValueError:
        print(f"ERROR: TG_API_ID 不是整数: {api_id!r}", file=sys.stderr)
        return 2
    if not phone.startswith("+"):
        print(f"ERROR: TG_PHONE 需带区号，如 +8613800000000，当前={mask_phone(phone)}", file=sys.stderr)
        return 2

    try:
        from telethon.sync import TelegramClient
    except ImportError:
        print("ERROR: 未装 telethon。见 spike-probe/README.md", file=sys.stderr)
        return 2

    print(f"[*] api_id={api_id_int}  phone={mask_phone(phone)}  mode={args.mode}")

    session_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "probe_session")
    client = TelegramClient(session_path, api_id_int, api_hash)

    results = {}
    try:
        client.connect()
        if not client.is_connected():
            print("ERROR: 无法连接 Telegram", file=sys.stderr)
            return 1

        if args.mode == "qr":
            results["qr"] = run_qr(client)
        else:
            modes = ["bare", "app_hash"] if args.mode == "all" else [args.mode]
            for m in modes:
                results[m] = run_one(client, m, phone)
    finally:
        try:
            client.disconnect()
        except Exception:  # noqa: BLE001
            pass

    print("\n===== 汇总 =====")
    for m, r in results.items():
        print(f"{m:10s} -> {r}")

    final = results.get(args.mode, next(iter(results.values()), "UNKNOWN"))
    print(f"\nRESULT: {final}")

    if final.startswith("FLOOD_WAIT"):
        print("提示：号码当日认证额度已耗尽，需等待后再试（不要在短时间内重试）。")
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
