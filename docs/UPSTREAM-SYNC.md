# 跟随官方升级同步（保留登录与去广告改动）

本仓库是 [DrKLO/Telegram](https://github.com/DrKLO/Telegram)（GPLv2）的 fork。

> **当前状态（2026-11-11）**：已同步到官方 **13.2.1**（`7be672e`，7291）。下次官方发版时按本文流程操作即可。
我们的改动全部集中在 4 个小组提交里，做法是：**始终让 `feat/no-sms-login-no-ads` 分支
「rebase 到官方最新版本 + 重放我们的 4 个 commit」**，而不是把官方更新 merge 进来。
这样历史始终是「官方版本 + 一层薄补丁」，冲突面最小、回滚最简单。

## 1. 仓库拓扑（一次性配置）

| 远端 | 地址 | 用途 |
|---|---|---|
| `origin` | `https://github.com/<你的用户名>/<仓库名>.git` | 我们的 fork，日常 push |
| `upstream` | `https://github.com/DrKLO/Telegram.git` | 官方源码，只 fetch 不 push |

创建 fork 后执行一次：

```bash
cd <repo-root>

# 原来的 origin 指向官方，改名为 upstream
git remote rename origin upstream
git remote add origin https://github.com/<你的用户名>/<仓库名>.git

# 本地 master 跟随官方 master（只读镜像，不承载我们的改动）
git fetch upstream --tags
git switch master
git branch --set-upstream-to=upstream/master
git switch feat/no-sms-login-no-ads
git branch --set-upstream-to=origin/feat/no-sms-login-no-ads   # 首次 push 后
```

验证：

```bash
git remote -v          # origin = 你的 fork；upstream = DrKLO/Telegram
git log --oneline -5   # 顶部的 4 个提交应为 feat(ads)/feat(login)/fix(login)
```

> GitHub 网页上的 **「Sync fork」按钮只同步 `master`**，不要把 master 合进 feature 分支；
> 升级一律走下面的本地 rebase 流程。

## 2. 升级流程（每次官方发版）

```bash
cd <repo-root>

# 1) 取官方最新代码与 tag
git fetch upstream --tags --prune

# 2) 查看官方最新版本（官方在 11.x 之后不再打 tag，直接看 master 日志）
git log --oneline -3 upstream/master
# 提交信息形如：7be672e update to 13.2.1 (7291)

# 3) 在 feature 分支上操作，并留一个升级前备份指针
git switch feat/no-sms-login-no-ads
git status --porcelain          # 必须干净
git branch backup/pre-sync-$(date +%Y%m%d)

# 4) rebase 到目标版本（默认 upstream/master；也可指定任意 tag/commit）
./scripts/sync-upstream.sh
# 或指定版本：
# ./scripts/sync-upstream.sh 7be672e
# 或手工：
# git rebase upstream/master

# 5) 冲突解决后构建 + 真机冒烟（见 §2.2）
./scripts/build-debug.sh
```

### 2.1 冲突预期与处理

我们的改动只碰 6 个文件，绝大多数上游升级不会冲突：

| 文件 | 改动 | 冲突概率 | 处理建议 |
|---|---|---|---|
| `LoginActivity.java` | 新增 `VIEW_QR` 页 + 轮询/迁移/2FA（约 +380 行） | **高** | 这是最可能冲突的文件。以官方新结构为准，把我们的 QR 页重新接进去；改动点见 `docs/MODIFICATIONS.md` |
| `res/values/strings.xml` | 新增 12 条 `LoginQr*` 文案 | 中 | 纯新增，冲突时保留双方即可 |
| `BuildVars.java` | 新增 `HIDE_SPONSORED` 常量 | 低 | 纯新增一行，取并集 |
| `MessagesController.java` / `ChatActivity.java` / `DialogsSearchAdapter.java` / `VideoAds.java` | 各 2–4 行短路 | 低 | 改动极小，按注释 `[patch G2]` 定位 |

冲突较多（尤其 `LoginActivity.java` 被官方大改）时，**放弃逐个 hunk 手工合并**，改用补丁序列重放：

```bash
# 从干净的上游版本新建分支
git switch -c feat/no-sms-login-no-ads-new <官方tag>
git am patches/0001-*.patch patches/0002-*.patch patches/0003-*.patch patches/0004-*.patch
# 逐个解决冲突（git am --continue），然后与旧分支对比确认改动等价
git diff feat/no-sms-login-no-ads..HEAD --stat
```

`patches/` 由 `./scripts/export-patches.sh` 生成，任何时候都可以重新导出最新版本。

### 2.2 升级后必须做的验证（约 10 分钟）

1. 构建通过：`./scripts/build-debug.sh` 退出码 0，日志有 `BUILD SUCCESSFUL`；
2. 安装 debug 包（包名带 `.beta`，不影响日用包）；
3. 冒烟：
   - 登录页出现「通过二维码登录」入口；二维码可生成、可轮询；
   - 已登录的旧手机扫码确认后，新设备完成登录（含 2FA 账号走密码页）；
   - 频道/搜索中不再出现赞助消息与推荐频道；视频/图片查看器无贴片广告；
   - 常规收发消息、切聊天正常（防回归）。
4. 全部通过后再 `./scripts/build-release.sh` 并安装日用。

### 2.3 push 与发布

```bash
# 升级验证通过后，用 --force-with-lease 推送 rebase 后的分支
git push --force-with-lease origin feat/no-sms-login-no-ads

# 打标签触发 GitHub Actions 自动构建并发 Release（APK 由 CI 产出）
git tag v13.2.1
git push origin v13.2.1
```

> 标签只需在发布时打；日常同步不必打标签。CI 构建约 30–60 分钟，完成后在仓库
> **Releases** 页面下载对应版本 APK（详见 `docs/BUILD.md` §6）。

> rebase 会重写历史，普通 push 会被拒绝；`--force-with-lease` 比 `-f` 安全（远端只允许快进到本地的预期状态）。

## 3. 回滚

| 场景 | 操作 |
|---|---|
| 构建失败 / 冒烟不过，想放弃本次升级 | `git rebase --abort`（进行中）；或 `git reset --hard backup/pre-sync-<日期>` |
| 推送后发现问题 | 在 GitHub 上恢复到备份分支，或本地 `git reset --hard` 后 `git push --force-with-lease` |
| 只想临时关掉去广告改动 | 把 `BuildVars.HIDE_SPONSORED` 改为 `false`（无需回滚其他代码） |
| 只想临时关掉扫码入口 | 见 `docs/MODIFICATIONS.md` 的关闭方法 |

## 4. 常见问题

| 问题 | 说明 |
|---|---|
| `git rebase` 提示 `unstaged changes` | 先提交或 stash；升级必须在干净工作区进行 |
| 冲突里出现 `.ai/` 文档 | 旧版升级可能残留 `.ai/`；当前版本已把文档统一到 `docs/`，直接删除 `.ai/` 冲突项 |
| 构建提示 `local.properties` 缺失 | 见 `docs/BUILD.md` §2 |
| 不知道官方最新版是哪个 | `git fetch upstream && git log --oneline -3 upstream/master`；提交信息形如 `update to 13.2.1 (7291)`。官方 11.x 之后已不再打 tag，统一用 `upstream/master` |
| fork 页面提示 behind upstream | 属正常——我们的 feature 分支基于某个官方 tag；需要升级时按本文流程操作 |
