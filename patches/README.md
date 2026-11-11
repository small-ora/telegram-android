# 补丁序列（本分支相对官方 13.1.1 的代码改动）

这 4 个 patch 从官方基线 `3de37c8`（13.1.1）出发，只包含**代码改动**（不含文档/SPEC 提交），
用于两种场景：

1. `git rebase` 冲突多、`LoginActivity.java` 被官方大改时的**手工重放**；
2. 仓库历史损坏/丢失时的**灾难恢复**（补丁内容与提交等价）。

```bash
# 在干净的上游版本上按顺序应用
git switch -c feat/no-sms-login-no-ads-new <官方版本>
git am patches/0001-*.patch patches/0002-*.patch patches/0003-*.patch patches/0004-*.patch
```

| 文件 | 对应提交 | 内容 |
|---|---|---|
| `0001-feat-ads-bot-G2.patch` | `ca4085c` | 去广告：频道/Bot 赞助消息 + 搜索推荐频道 |
| `0002-feat-ads-VideoAds.patch` | `bc9e3c6` | 去广告：视频/图片查看器贴片 |
| `0003-feat-login-G1-a.patch` | `de96d77` | 扫码登录（新设备侧） |
| `0004-fix-login-dp.patch` | `1437581` | 二维码页尺寸修复 + 日志 |

重新生成（分支历史变化后）：

```bash
./scripts/export-patches.sh          # 基线自动取与 upstream/master 的 merge-base
```

完整说明见 `docs/UPSTREAM-SYNC.md`、`docs/MODIFICATIONS.md`。
