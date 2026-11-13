# 安装失败根因与修复：APK 被标记 `android:testOnly`（2026-11-13）

> **现象**：从 GitHub Release 下载的 APK，在手机上直接点击安装只提示
> 「安装失败 / 应用未安装」，**没有任何错误码或详情**（覆盖安装与全新安装都一样）。
> **结论**：与签名、版本号无关。AGP 的注入构建参数 `-Pandroid.injected.build.abi=arm64-v8a`
> 会给 APK 打上 `android:testOnly="true"`，Android 系统安装器拒绝安装 test-only 包
> （只有 `adb install -t` 能装）。v13.1.1、v13.2.1 的 Release APK 均受影响；
> v13.2.2 起修复，并在 CI 增加强制门禁。

## 1. 证据：Release APK 清单带 testOnly

下载 Release APK 后直接解析打包清单：

```text
$ aapt2 dump xmltree --file AndroidManifest.xml tg-client-13.2.1-7291-arm64-release.apk | grep testOnly
        A: http://schemas.android.com/apk/res/android:testOnly(0x01010272)=true

$ aapt2 dump xmltree --file AndroidManifest.xml tg-client-13.1.1-7237-arm64-release.apk | grep testOnly
        A: http://schemas.android.com/apk/res/android:testOnly(0x01010272)=true
```

`testOnly=true` 的 APK 只能由 `adb install -t` / `pm install -t`（允许测试包）安装；
从手机文件管理器、浏览器、系统安装器点击安装会失败，且 Android/HyperOS 通常只显示
「安装失败/应用未安装」这种无细节提示——与用户看到的完全一致。

## 2. 对照实验（AGP 8.13.2，只跑清单产出任务，不编译代码）

用 `:TMessagesProj_App:processAfatReleaseManifestForPackage` 生成真正打进 APK 的清单：

| 构建参数 | 打包清单 | 结论 |
|---|---|---|
| 默认（不加任何 `android.injected.*`） | 无 `testOnly` | 正常可装 |
| `-Pandroid.injected.build.abi=arm64-v8a`（**原 CI/脚本用法**） | `testOnly="true"` | 手机端无法安装 |
| `-Pandroid.injected.build.abi=arm64-v8a -Pandroid.injected.testOnly=false` | **与默认逐字节一致** | 修复且无副作用 |

同一实验在 13.2.1（`7be672e`）与 13.2.2（`21f7d109`）两个基线上各做一次，结论一致；
13.2.2 上「默认」与「加 `testOnly=false`」两份打包清单 sha256 前 12 位相同（`deeb14f232b4`）。

## 3. 排除项（为什么不是签名/版本问题）

| 检查 | 结果 |
|---|---|
| 包名 | 均为 `org.telegram.messenger`，一致 |
| versionCode | 13.2.1 为 `72919` > 已装旧版 `72379`（非降级） |
| 签名证书 SHA-256 | `a08d7dc3…229ab`，与 v13.1.1 / 本地历史 release 完全一致（非签名冲突） |
| minSdk / targetSdk | `23 / 36`，设备（Android 17）满足 |
| APK 完整性 | `sha256sum -c` 通过、`apksigner verify` 通过、zip 结构正常 |

历史安装之所以能成功，是因为之前都是用 `adb install -r -t` 安装（`-t` 即“允许测试包”），
所以 testOnly 问题一直没有暴露，直到这次从手机端直接点安装。

## 4. 修复内容

| 文件 | 改动 |
|---|---|
| `.github/workflows/build-apk.yml` | 构建加 `-Pandroid.injected.testOnly=false`；改用 `assembleAfatRelease` 只产出 afat 风味；新增门禁：清单含 `testOnly` / 签名无效 / `versionCode ≠ APP_VERSION_CODE×10+9` 时直接失败，不发 Release |
| `scripts/build-release.sh` | 同样加 `-Pandroid.injected.testOnly=false`，构建后用 `aapt2` 校验清单无 `testOnly` |
| `scripts/build-debug.sh` | 同样加 `-Pandroid.injected.testOnly=false`（debug 包也能手机端直接安装） |
| `docs/BUILD.md` | 补充该坑的说明与排错表（含 `bundleAfat` 降级安装失败的区别） |

## 5. 验证

本地（Debian 12 / JDK 17.0.21 / SDK 36 / AGP 8.13.2）：

```text
# 清单对照实验（13.2.2 基线）
[A] 无注入参数                          testOnly_str=0  sha=deeb14f232b4
[B] -Pandroid.injected.build.abi         testOnly_str=1  sha=28bf084514ff
[C] 上述 + testOnly=false                testOnly_str=0  sha=deeb14f232b4   # 与 A 一致

# Java 编译
$ ./gradlew :TMessagesProj_App:compileAfatReleaseJavaWithJavac -Dorg.gradle.jvmargs=-Xmx3g ...
BUILD SUCCESSFUL in 1m 7s          # 退出码 0

# 仓库自检
$ ./scripts/repo-check.sh
== 自检通过 ==                      # 退出码 0
```

CI（GitHub Actions，tag `v13.2.2`）：见 §6。

## 6. CI 构建与产物验证（v13.2.2）

### 6.1 第一次构建（run `43447215564`）：构建成功、产物定位失败

- `assembleAfatRelease` 构建成功（`18m 5s`，335 tasks），但「校验产物」步骤报
  `find: 'TMessagesProj_App/build/outputs/apk': No such file or directory`；
- 根因：带 `-Pandroid.injected.build.abi` 时 AGP 把 APK 输出到
  `TMessagesProj_App/build/intermediates/apk/<flavor>/<type>/`（IDE 注入构建路径），
  而不是 `build/outputs/apk/`；
- 修复：提交 `0420ea34b` 让 CI 与本地脚本同时搜索 `outputs/apk` 与 `intermediates/apk`，
  找不到时打印候选 APK；重打 tag 触发第二次构建。

### 6.2 第二次构建（run `43451933143`）—— 通过

- Run：<https://github.com/small-ora/telegram-android/actions/runs/43451933143>
  （2026-11-13 15:22:15Z → 15:49:18Z，**27m03s**，冷缓存）；
- 10 个步骤全部 `success`：构建 → **校验（无 testOnly / 证书指纹 / versionCode）** → 上传 Artifacts
  → 创建 Release `v13.2.2`（APK + sha256）；
- 校验步骤关键输出：`✅ 清单无 testOnly，可正常安装`、`✅ 签名证书与历史 Release 一致`、
  `versionCode='73039'`（= 7303×10+9，afat 风味）。

### 6.3 产物验证（下载 Release APK 后实测）

```text
$ sha256sum -c tg-client-13.2.2-7303-arm64-release.apk.sha256
tg-client-13.2.2-7303-arm64-release.apk: OK
# 与 GitHub 资产 digest 一致：8b40c63cd9ca473ffbe8bf6b3a71a4ebb8840b4cc676100e61a6f987a00f80ca

$ apksigner verify --print-certs ...
Signer #1 certificate SHA-256 digest: a08d7dc323ddf71ef3201944397e0d3cce7d40847263e11f328b68bbe19229ab
# 与 v13.1.1 / v13.2.1 / 本地历史 release 相同 → 同签名可覆盖升级

$ aapt2 dump badging ...
package: name='org.telegram.messenger' versionCode='73039' versionName='13.2.2'
minSdkVersion:'23'   targetSdkVersion:'36'   native-code: 'arm64-v8a' ...

$ aapt2 dump xmltree --file AndroidManifest.xml ... | grep testOnly
# （无输出）—— 关键：不再带 android:testOnly，手机端可直接点击安装
```

- 文件：`tg-client-13.2.2-7303-arm64-release.apk`，43,252,127 字节，v1+v2 签名；
- 与已装旧版（versionCode `72379`/`72919`）同签名且版本更高 → 可直接覆盖升级。

## 7. 影响范围与回滚

- **受影响版本**：`v13.1.1`、`v13.2.1` 的 Release APK（手机端直接安装会失败；仍可用 `adb install -t` 安装）。
  两个旧 Release 保留不删，Release 说明均已补警告并指向 v13.2.2。
- **v13.2.2**：修复后可直接下载安装；与旧版同签名、versionCode 更高，可覆盖升级。
- 回滚：`git reset --hard <旧 commit>` 后重新打 tag 构建；构建参数本身无数据/配置副作用。
