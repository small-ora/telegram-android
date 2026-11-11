# S3 去广告（G2）实现记录（2026-11-02）

> 结论：代码改动**已完成并本地提交**（commit `ca4085c`），`assembleDebug` 退出码 0。
> **真机验证（AC-5 / AC-6）未做**：当前无 adb 设备连接，需你 sideload APK 后验收。
> 本步依据 `recon/source.md` 与「去广告只读勘察报告」（2026-11-02）。

## 1. 改动清单（4 文件 / +10 −2）

| 文件 | 位置 | 改动 | 作用 |
|---|---|---|---|
| `TMessagesProj/.../messenger/BuildVars.java` | `IS_BILLING_UNAVAILABLE` 之后 | 新增 `public static final boolean HIDE_SPONSORED = true;` | 单一开关，便于日后再放开 |
| `.../messenger/MessagesController.java` | `getSponsoredMessages` 首行 | `if (BuildVars.HIDE_SPONSORED) return null;` | **请求侧短路**：不再发 `messages.getSponsoredMessages`，不建缓存、不广播 |
| `.../ui/ChatActivity.java` | `addSponsoredMessages` 的 guard 首项 | `BuildVars.HIDE_SPONSORED ||` | **渲染侧短路**：不插入广告消息、不插入 bot 广告条 |
| `.../ui/Adapters/DialogsSearchAdapter.java` | `searchDialogs` 的 sponsored 门控 | `|| BuildVars.HIDE_SPONSORED` | **请求侧短路**：不再发 `contacts.getSponsoredPeers`，搜索列表无推荐频道 |

diff（完整）：`git show ca4085c` / `git diff ecd0b17..ca4085c`

## 2. 为什么选这两个短路点（勘察结论）

- `getSponsoredMessages` 全项目只有 2 个调用方，且**都判空**（`ChatActivity:25212`、`ChatActivity:25267`）；方法本身在「无缓存/异步请求中」时就会返回 `null`（`MessagesController:21675/21765`），所以「返回 null」是**既有契约**，不引入新的 NPE 面。
- `addSponsoredMessages` 本来就有「`res == null` 直接 return」的线上路径（`:25212`），渲染侧短路与它同构；短路后 4 个状态字段（`sponsoredMessagesAdded` / `sponsoredMessagesPostsBetween` / `notPushedSponsoredMessages` / `botSponsoredMessage`）保持初值，所有消费点均已判空或按 0/null 处理。
- `contacts.getSponsoredPeers` 的门控里本就有「premium 且已关闭广告 → 不发请求」的现成路径（`DialogsSearchAdapter:1134`），本改动等于让该路径恒成立；同方法内随后必有 `notifyDataSetChanged()`，不会留下 loading 残留。
- 只做请求侧短路即可让「内容根本不进列表」，因此**没有动消息管线**（`processNewMessages` / `messagesDict` / `findAdPlace` 未改），符合 SPEC R4 的缓解要求。

## 3. 副作用（明确记录）

| 副作用 | 说明 | 是否可接受 |
|---|---|---|
| bot 内广告条一并消失 | `botSponsoredMessage` 与频道广告同源（`getSponsoredMessages`），短路后恒 null | ✅ 属「去广告」目标内 |
| 广告曝光/点击统计不再上报 | 4 类 `*SponsoredMessage` 请求都不会触发；无「必须上报否则异常」的逻辑 | ✅ 自用构建无收益需求 |
| 服务端账号级「关闭广告」状态不同步 | 本实现不发 `account.toggleSponsoredMessages`，只影响本设备 | ✅ 符合最小改动 |
| `PremiumPreviewFragment` 的 "Show ads" 开关仍存在 | 那是官方 Premium 页面，未改；对非 premium 无效 | ✅ 保留官方原样 |
| 广告相关 UI 变为死代码 | `ReportBottomSheet` 等未删，保留以减少回滚面 | ✅ |

## 4. 明确不动的地方（防止误伤）

- `ui/bots/BotAdView.java`（数据源已断，无需改）
- `ui/PremiumPreviewFragment.java`（自家 Premium 推广页 + 官方关广告开关）
- `ui/ChannelMonetizationLayout.java`（频道主收益统计，非广告位）
- `ui/Components/DialogsChannelsAdapter.java` 的「相似频道推荐」（非付费广告）
- ~~`messenger/video/VideoAds.java`（视频/图片查看器贴片广告）~~ —— **Q3 你已选 A（一并去掉），见 §8**

## 5. 验证证据

| 项 | 结果 |
|---|---|
| 编译命令 | `./gradlew :TMessagesProj_App:assembleDebug -Pandroid.injected.build.abi=arm64-v8a -Dorg.gradle.jvmargs=-Xmx4g --max-workers=6 --console=plain` |
| 退出码 | **0** |
| 结果行 | `BUILD SUCCESSFUL in 1m 35s`（301 tasks: 10 executed, 291 up-to-date） |
| 日志 | `docs/evidence/logs/build-S3b-20261102-093242.log` |
| 上次提交（改动前）也绿 | `BUILD SUCCESSFUL in 6m 32s`（`evidence/M1-build-result.md`） |
| 产物 | `TMessagesProj_App/build/intermediates/apk/afat/debug/app.apk`（重新生成） |
| 运行期验证 | ❌ **未做**（无 adb 设备）：需真机看「频道底部无广告行 / bot 顶部无广告条 / 搜索 ≥4 字符无推荐频道」 |

## 6. 回滚

```bash
# 整步回滚（推荐）
git revert --no-edit ca4085c
# 或临时放开开关（改一处、重新编译）
# BuildVars.HIDE_SPONSORED = false
```

## 7. Q3 决策落地（2026-11-02 你选 A）

`VideoAds` 一并去掉，独立 commit `bc9e3c6`（1 文件 +4），编译绿 1m36s：
`VideoAds.load()` 首行 `if (BuildVars.HIDE_SPONSORED) return;` → 不再请求 `messages.getSponsoredMessages(flags|=1)`，
`cache.loaded` 永不为真 → `schedule()/show()` 自动空转；`make()` 不返回 null，`PhotoViewer` 调用点安全。
