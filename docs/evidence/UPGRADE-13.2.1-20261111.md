# 升级同步官方 13.2.1 记录（2026-11-11）

> 目标：把「扫码登录 + 去广告」改动 rebase 到官方最新版 **13.2.1（`7be672e`，7291）**，
> 保留全部改动，并由 GitHub Actions 重新构建、发布 v13.2.1 Release。
> 结论：**rebase 成功（仅 1 处 import 冲突）→ CI 构建成功 → Release v13.2.1 已发布，APK 校验通过**。
> 真机冒烟（扫码登录 / 去广告 / 常规收发）待用户安装后确认。

## 1. 同步对象

| 项 | 值 |
|---|---|
| 旧基线 | 13.1.1（`3de37c8`，7237） |
| 新基线 | **13.2.1（`7be672e`，7291）**，官方 master（2026-11-07） |
| 变更规模 | 4,737 个文件 / +857,481 / −44,099（官方大版本，含 TL schema 与 ThemeBind 改版） |
| 本地操作分支 | `sync/13.2.1`（完成后 `feat/no-sms-login-no-ads` 指向同一历史） |
| 升级前备份 | 分支 `backup/pre-sync-13.2.1-20261111`（= `45fedaa4b`，13.1.1 版本） |

## 2. 同步过程

```bash
git fetch upstream --prune                    # upstream = DrKLO/Telegram
git switch -c sync/13.2.1 feat/no-sms-login-no-ads
git rebase upstream/master                    # 重放本分支 14 个提交
```

- 重放结果：**仅 1 处冲突**，位于 `LoginActivity.java` 的 import 区：
  - 上游新增：`com.google.firebase.pnv.VerificationSupportResult`
  - 本项目新增：`com.google.zxing.*`（二维码生成）
  - 解决：保留双方（互不影响）；
- 其余代码提交（去广告 4 文件、扫码登录、字符串）自动合并成功；
- 子模块按 13.2.1 新 pin 更新（`git submodule update --init --recursive`）。

## 3. 改动完整性检查

| 检查 | 结果 |
|---|---|
| 冲突标记残留（`<<<<<<<` 等） | 0 |
| `HIDE_SPONSORED` 开关与 4 处短路 | ✅ 全部存在（BuildVars / MessagesController / ChatActivity / DialogsSearchAdapter / VideoAds） |
| 扫码登录入口与 QR 页（`VIEW_QR=19`、`views[20]`、`LoginActivityQrView`） | ✅ 完整保留，无 ViewNumber 冲突 |
| `LoginQr*` 字符串（12 条） | ✅ 无重复 key（strings.xml 全量 11,549 条无重复） |
| zxing 依赖 | ✅ 上游仍保留 `com.google.zxing:core:3.5.4` |
| 版本号 | ✅ `APP_VERSION_NAME=13.2.1` / `APP_VERSION_CODE=7291` |

## 4. 编译验证

本机内存仅 8 GB，13.2.1 的 Kotlin 生成代码显著增多，直接全量构建触发 OOM；改用受限内存只做 Java 编译校验：

```text
$ ./gradlew :TMessagesProj_App:compileAfatReleaseJavaWithJavac \
    -Dorg.gradle.jvmargs=-Xmx3g -Pkotlin.compiler.execution.strategy=in-process \
    --max-workers=2 --no-daemon
BUILD SUCCESSFUL in 1m 6s      # 退出码 0
```

完整的 APK 构建由 GitHub Actions 托管 runner（16 GB）执行。

## 5. CI 构建与 Release

| 项 | 值 |
|---|---|
| 推送 | `git push --force-with-lease origin feat/no-sms-login-no-ads`（rebase 改写历史）+ tag `v13.2.1` |
| Actions run | [43003511139](https://github.com/small-ora/telegram-android/actions/runs/43003511139) |
| 结果 | ✅ 14 个步骤全部 success，耗时约 **21 分 36 秒**（Gradle 缓存命中，较首次 33 分钟更快） |
| Release | <https://github.com/small-ora/telegram-android/releases/tag/v13.2.1> |
| APK | `tg-client-13.2.1-7291-arm64-release.apk`（43,038,007 字节）+ `.sha256` |

### 5.1 APK 验证（下载后实测）

```text
$ sha256sum -c tg-client-13.2.1-7291-arm64-release.apk.sha256
tg-client-13.2.1-7291-arm64-release.apk: OK

$ apksigner verify --print-certs ...
Signer #1 certificate SHA-256 digest: a08d7dc323ddf71ef3201944397e0d3cce7d40847263e11f328b68bbe19229ab

$ aapt2 dump badging ...
package: name='org.telegram.messenger' versionCode='72919' versionName='13.2.1'
```

- 签名证书与 v13.1.1 Release **完全一致** → 可直接覆盖升级（从 13.1.1 自用版升级无需卸载）；
- 版本：`13.2.1`，versionCode `72919`（官方 7291 × 10 + arm64 后缀），包名 `org.telegram.messenger`；
- 若从**官方 Telegram** 切换，仍因签名不同需先卸载官方版。

## 6. 待用户验证（AC 冒烟）

| 项 | 状态 |
|---|---|
| 安装 v13.2.1 并覆盖升级 v13.1.1 | ⏳ 待用户安装 |
| 扫码登录（登录页入口 → 旧设备扫码 → 2FA → 进入会话列表） | ⏳ 待用户实测 |
| 去广告（频道赞助消息 / 搜索推荐 / 视频贴片） | ⏳ 待用户实测 |
| 常规功能无回归（收发消息、切换聊天、媒体） | ⏳ 待用户实测 |

> 注：13.2.1 官方重构较大（ThemeBind / FPNV 等），虽编译与签名验证通过，
> 仍建议真机确认扫码登录与去广告实际生效后再长期日用。

## 7. 回滚

```bash
# 回到 13.1.1 版本（本地）
git reset --hard backup/pre-sync-13.2.1-20261111
git push --force-with-lease origin feat/no-sms-login-no-ads

# 撤销 v13.2.1 Release（GitHub 网页或 gh 命令）
gh release delete v13.2.1 -R small-ora/telegram-android --yes
git push origin :refs/tags/v13.2.1
```
