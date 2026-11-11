# 探针：`auth.exportLoginToken` 的轮询行为（2026-11-02）

> 目的：决定客户端二维码刷新策略（每 2s 换新码 vs 到期再刷新、以及确认延迟）。
> 方式：Telethon 未登录连接连续调用 `auth.exportLoginToken`，间隔 2s，共 4 次。
> 脚本：`tools/probe/probe_qr_poll.py`（只读调用，不发短信、不登录、不写账号数据）

## 实测结果

```
[0] type=LoginToken ttl=23s len=34
[1] type=LoginToken ttl=20s len=34
[2] type=LoginToken ttl=18s len=34
[3] type=LoginToken ttl=16s len=34
token 是否每次不同: False (去重 1/4)
```

## 结论（S4 实现依据）

| 观察 | 含义 | 对实现的约束 |
|---|---|---|
| 4 次调用返回**同一个 token**（去重 1/4） | 服务端在 token 有效期内复用同一 token，不会因轮询而作废旧码 | **可以每 2s 轮询**而不打扰用户扫码；二维码只在 token 变化时重绘 |
| `expires` 逐次递减（23→16s），首次约 30s 有效期 | token 有固定 TTL（≈30s，本机时钟/服务器时间差使首测显示 23s） | 到期前必须重新 `export` 才能续期；用 `ConnectionsManager.getCurrentTime()` 做时间基准 |
| 返回类型为 `LoginToken` | 未登录连接可直接调用，无需先建正式会话 | 与 `auth.sendCode` 相同的发送方式与 flags 即可 |

> 备注：确认（旧设备扫码同意）后服务端会把下一次 `export` 的返回变成 `LoginTokenSuccess`，因此轮询间隔直接决定「扫码后多久进入会话列表」，2s 是可接受值。
