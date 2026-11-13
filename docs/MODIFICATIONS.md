# 修改记录（GPLv2 要求）

本项目是 [DrKLO/Telegram](https://github.com/DrKLO/Telegram) 的修改版（fork），
依据 GNU GPL v2 分发。本文记录相对官方源码的全部修改，供许可证合规与后续维护使用。

## 0. 基线与声明

| 项 | 值 |
|---|---|
| 上游项目 | `https://github.com/DrKLO/Telegram`（Telegram Android 官方源码） |
| 上游版本 | **13.2.2**（提交 `21f7d109`，`update to 13.2.2 (7303)`）；改动初版基于 13.1.1（`3de37c8`） |
| 许可证 | GNU GPL v2（见仓库根 `LICENSE`） |
| 修改日期 | 2026-11-02（初版改动）；2026-11-11（rebase 同步到官方 13.2.1）；2026-11-13（rebase 同步到官方 13.2.2） |
| 修改性质 | 个人自用分支：登录方式与广告展示两处功能修改，不改变服务端/协议之外的行为 |
| 分发说明 | 分发本项目的二进制（APK）时须同时提供本源码仓库；不得使用「Telegram」名称/官方图标暗示官方身份 |

> 本 fork 与 Telegram 官方无任何关联。默认沿用上游源码内的共享 `api_id = 4`，
> 仅建议个人测试/自用；正式分发前应申请自己的 `api_id` 并遵守 Telegram API 条款。

## 1. 修改清单

分支：`feat/no-sms-login-no-ads`，共 4 个代码提交（rebase 后为 `7be672e..HEAD`；提交号因 rebase 重写，内容等价）。

| # | 提交 | 主题 | 修改文件 |
|---|---|---|---|
| 1 | `91da4a6` | 去广告：频道/Bot 内赞助消息 + 搜索推荐频道 | `BuildVars.java`、`MessagesController.java`、`ChatActivity.java`、`DialogsSearchAdapter.java` |
| 2 | `3ed45d7` | 去广告：视频/图片查看器贴片 | `video/VideoAds.java` |
| 3 | `adf0c7d` | 新增扫码登录（新设备侧） | `LoginActivity.java`、`res/values/strings.xml` |
| 4 | `c6949ed` | 二维码页尺寸修复 + 扫码链路错误日志 | `LoginActivity.java` |

查看完整差异：

```bash
git diff 7be672e..HEAD --stat
git diff 7be672e..HEAD
git show <commit>
```

## 2. 改动一：去除广告（开关控制）

**行为**：不请求、不渲染以下广告位。

| 广告位 | 修改点 | 方式 |
|---|---|---|
| 频道 / Bot 内赞助消息 | `MessagesController.getSponsoredMessages()` | 开关为真时直接返回 `null`（不发 `messages.getSponsoredMessages`） |
| 频道 / Bot 内赞助消息渲染 | `ChatActivity.addSponsoredMessages()` | 开关为真时直接 return，不插入广告消息 |
| 会话搜索推荐频道 | `DialogsSearchAdapter` 搜索逻辑 | 开关为真时不发 `contacts.getSponsoredPeers` |
| 视频/图片查看器贴片 | `video/VideoAds.java` | 开关为真时短路 |

**总开关**：`TMessagesProj/src/main/java/org/telegram/messenger/BuildVars.java`

```java
// [patch G2] 自用构建：永久关闭官方广告位
public static final boolean HIDE_SPONSORED = true;
```

- 改为 `false` 即恢复官方广告行为（无需改动其他文件）；
- 该开关是 `final` 常量，修改后需重新编译。

### 2.1 与上游 13.2.1 的关系（2026-11-11 同步后）

- 上游 13.2.1 自身新增了「按会话隐藏赞助消息」的官方开关（`ChatActivity.OPTION_HIDE_SPONSORED_MESSAGE`），
  并在主题系统引入 `ThemeBind`；本项目 `HIDE_SPONSORED` 仍是**全局强制**开关，二者不冲突。
- 同步方式为 rebase 到 `upstream/master`（`7be672e`），只有一个 import 冲突（上游新增 FPNV、我们新增 zxing 二维码 import），
  已按「保留双方」解决；扫码登录/去广告的逻辑未改写。
- 验证：`compileAfatReleaseJavaWithJavac` 退出码 0；CI 构建与 Release 见 `docs/evidence/UPGRADE-13.2.1-20261111.md`。

## 3. 改动二：扫码登录（新设备侧）

**行为**：登录页新增「通过二维码登录」入口，用已登录的旧手机扫码确认即可登录，无需短信验证码。

| 模块 | 实现 | 文件 |
|---|---|---|
| 新页面 | `VIEW_QR`（`ViewNumber` 增加 `VIEW_QR = 19`，`views` 19→20，`createView` 实例化 `LoginActivityQrView`） | `LoginActivity.java` |
| 入口 | 手机号登录页底部「通过二维码登录」按钮（主题色） | `LoginActivity.java` |
| 协议 | 未登录态调用 `auth.exportLoginToken`（带 `WithoutLogin`/`EnableUnauthorized` 等标志，与 `auth.sendCode` 一致） | `LoginActivity.java` |
| 二维码 | `tg://login?token=` + `Base64(URL_SAFE \| NO_WRAP)`，按官方 `SessionsActivity/CameraScanActivity` 的编码/校验规则 | `LoginActivity.java` |
| 轮询 | 每 2 秒 `export`；token 未变则复用二维码，TTL 过期/失败按 2s→4s→8s→16s 退避，`FLOOD_WAIT_X` 按其秒数等待 | `LoginActivity.java` |
| DC 迁移 | `loginTokenMigrateTo` → 向目标 DC 发 `auth.importLoginToken`，成功后再 `setDefaultDatacenterId` | `LoginActivity.java` |
| 登录完成 | `loginTokenSuccess.authorization` → 复用官方 `onAuthSuccess()` 完成账号初始化 | `LoginActivity.java` |
| 2FA | 401 `SESSION_PASSWORD_NEEDED` → `account.getPassword` → 官方 `VIEW_PASSWORD` 云密码页 | `LoginActivity.java` |
| 文案 | 新增 12 条 `LoginQr*` 字符串（中文直写，远程语言包不含这些 key） | `res/values/strings.xml` |
| 错误日志 | `logQr` 记录导出/迁移/import 结果与服务端错误码 | `LoginActivity.java` |

**关闭方式**：删除/隐藏手机号页的入口按钮即可（`LoginActivity` 中「通过二维码登录」按钮的创建处），
或回滚提交 `de96d77` / `1437581`；官方原有的手机号/短信/邮箱登录路径完全保留、未修改。

**限制**（非缺陷，记录在 `docs/evidence/S4-qr-login.md` §3）：
- 「复制登录链接」仅供引导：官方客户端（含本 fork）对 `tg://login?token=` 深链只弹提示，不能替代扫码；
- 新页面文案为中文硬编码，英文界面下仍显示中文；
- passkey 登录在自签名构建上不可用（Telegram `assetlinks.json` 只授权官方签名）。

## 4. 未修改的部分（重要）

- 未修改任何服务端协议、加密、账号体系、api_id/api_hash、包名（release 仍为 `org.telegram.messenger`）；
- 未引入新的第三方依赖；
- 未修改官方登录的短信/邮箱/2FA 流程，仅新增二维码入口；
- 未修改广告请求之外的网络行为。

## 5. 如何验证改动仍在

```bash
# 去广告开关存在且为 true
grep -n 'HIDE_SPONSORED' TMessagesProj/src/main/java/org/telegram/messenger/BuildVars.java

# 扫码登录入口存在
grep -n 'VIEW_QR\|exportLoginToken\|LoginActivityQrView' \
  TMessagesProj/src/main/java/org/telegram/ui/LoginActivity.java | head

# 相对基线的完整差异（应有 7 个文件、约 +450/−14）
git diff 7be672e..HEAD --stat
```

## 6. 相关文档

- 需求与验收标准：`docs/spec/SPEC-v2.1-frozen.md`、`docs/spec/SPEC-v2.2-proposal.md`
- 源码勘察（行号级定位）：`docs/recon/source.md`
- 实现与验证证据：`docs/evidence/S3-ads-removal.md`、`docs/evidence/S4-qr-login.md`、`docs/evidence/S7-realtime-validation.md`
- 升级维护：`docs/UPSTREAM-SYNC.md`
