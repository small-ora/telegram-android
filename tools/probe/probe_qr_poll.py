#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""探针：连续调用 auth.exportLoginToken，观察 token 是否每次变化、TTL 多长。
用于决定客户端二维码刷新策略（每 2s 新码 vs 到期再刷新）。
安全边界：只读调用；不发短信、不登录、不写账号数据。
"""
import asyncio, base64, os, time
from telethon import TelegramClient, errors
from telethon.tl.functions.auth import ExportLoginTokenRequest

API_ID = 4
API_HASH = "014b35b6184100b085b0d0572f9b5103"
HERE = os.path.dirname(os.path.abspath(__file__))


def b64url(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).decode()


async def main():
    client = TelegramClient(os.path.join(HERE, "probe_session"), API_ID, API_HASH)
    await client.connect()
    if not client.is_connected():
        print("ERROR: 无法连接")
        return 1
    tokens = []
    try:
        for i in range(4):
            try:
                r = await client(ExportLoginTokenRequest(API_ID, API_HASH, []))
            except errors.FloodWaitError as e:
                print(f"[{i}] FLOOD_WAIT {e.seconds}s")
                break
            except errors.RPCError as e:
                print(f"[{i}] RPC_ERROR {type(e).__name__}: {e}")
                break
            name = type(r).__name__
            exp = getattr(r, "expires", None)
            tok = getattr(r, "token", None)
            now = int(time.time())
            print(f"[{i}] type={name} ttl={None if exp is None else int(exp.timestamp()) - now}s len={None if tok is None else len(tok)}")
            if tok:
                tokens.append(tok)
            await asyncio.sleep(2)
        if len(tokens) >= 2:
            print(f"token 是否每次不同: {len(set(tokens)) == len(tokens)} (去重 {len(set(tokens))}/{len(tokens)})")
        return 0
    finally:
        await client.disconnect()

if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
