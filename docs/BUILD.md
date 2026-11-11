# 构建指南

本文说明如何从源码构建本分支的 debug / release APK。上游为
[DrKLO/Telegram](https://github.com/DrKLO/Telegram)，构建方式与上游一致。

## 1. 环境要求

| 组件 | 版本 | 说明 |
|---|---|---|
| JDK | 17（如 `openjdk-17-jdk`） | 上游 AGP/Gradle 要求 |
| Android SDK | API 36 | `compileSdk` / `targetSdk` = 36 |
| build-tools | 36.0.0 | |
| NDK | 27.2.12479018 | 编译 native 部分 |
| CMake | 3.22.1 | |
| Gradle | 8.13（wrapper 自带，首次构建自动下载） | 无需预装 |
| 系统内存 | 建议 ≥ 8 GB 可用；`-Xmx4g` | 首次编译 native 较慢 |
| 磁盘 | 源码 + 构建缓存约 15–20 GB | |

本仓库已在 Debian 12 上验证通过（JDK 17.0.x / SDK 36 / NDK 27.2），证据见
`docs/evidence/M1-build-result.md` 与 `docs/evidence/S6-release-build.md`。

## 2. 初始化

```bash
cd <repo-root>

# 1) 子模块（首次 clone 必须；否则 native 编译失败）
git submodule update --init --recursive

# 2) 指向本地 SDK（该文件已被 .gitignore 忽略，不会提交）
echo "sdk.dir=$ANDROID_HOME" > local.properties

# 3) 环境变量
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ANDROID_HOME=/opt/android-sdk
export ANDROID_SDK_ROOT=/opt/android-sdk
```

## 3. 构建

脚本封装了以下命令（`scripts/env.sh` 统一设置环境变量）：

```bash
./scripts/build-debug.sh      # => TMessagesProj_App/build/outputs/apk/debug/*.apk
./scripts/build-release.sh    # => TMessagesProj_App/build/outputs/apk/release/*.apk
```

等价的原始命令：

```bash
./gradlew :TMessagesProj_App:assembleDebug \
  -Pandroid.injected.build.abi=arm64-v8a \
  -Dorg.gradle.jvmargs=-Xmx4g --max-workers=6 --console=plain
```

说明：

- 只编译 `arm64-v8a` 可显著缩短时间；需要其他 ABI 时去掉 `-Pandroid.injected.build.abi`。
- debug 包 `applicationId` 带 `.beta` 后缀（`org.telegram.messenger.beta`），可与官方版共存，
  但数据与 release 包**不互通**。
- release 包沿用仓库自带 `TMessagesProj/config/release.keystore`（上游公开测试签名），
  包名 `org.telegram.messenger`，**安装前需卸载官方版**。
- 如需长期覆盖升级：务必保留 `TMessagesProj/config/release.keystore` 与对应口令，更换签名后无法覆盖安装。
  该文件与上游仓库一致，不属于本项目的私有密钥。

## 4. 验证一次构建是否成功

```bash
set -o pipefail
./scripts/build-debug.sh > /tmp/build.log 2>&1
echo "exit=$?"
grep -E 'BUILD SUCCESSFUL|BUILD FAILED' /tmp/build.log
ls -lh TMessagesProj_App/build/outputs/apk/debug/*.apk
```

判据：退出码 0 且日志出现 `BUILD SUCCESSFUL`。

## 5. 常见问题

| 现象 | 原因 / 处理 |
|---|---|
| `SDK location not found` | 缺 `local.properties` 或 `ANDROID_HOME` 未设置 |
| native 编译报缺少头文件 / 子模块为空 | `git submodule update --init --recursive` |
| `OutOfMemoryError` 或 Gradle 卡死 | 降低 `--max-workers`，确认 `-Xmx4g` 生效；`./gradlew --stop` 后重试 |
| 首次构建很慢 | Gradle 需下载依赖 + 编译 native，属正常；后续增量构建 1–2 分钟 |
| release 安装失败 `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | 官方版/其他签名的同名包已存在，先卸载 |
| 扫码登录报 `AUTH_TOKEN_INVALID2` | 登录页勾选了「测试后台」：取消勾选后重试（详见 `evidence/S7-realtime-validation.md`） |

## 6. GitHub Actions 自动构建（推荐，无需本地环境）

仓库自带 [`.github/workflows/build-apk.yml`](../.github/workflows/build-apk.yml)，
在 GitHub 托管 runner 上构建 **已签名的 release APK** 并发布到 Releases：

| 方式 | 操作 | 结果 |
|---|---|---|
| 发版（推荐） | `git tag v13.1.1 && git push origin v13.1.1` | 构建 + 创建 Release + 上传 APK 与 sha256 |
| 只构建 | Actions → Build signed APK → Run workflow | 仅构建，产物在该次 run 的 Artifacts |

CI 使用的工具链与本地一致（JDK 17 / SDK 36 / build-tools 36.0.0 / NDK 27.2 / CMake 3.22.1），
签名沿用仓库自带 `TMessagesProj/config/release.keystore`（上游公开测试签名），因此：
- 与历史 CI Release 可直接覆盖升级；
- 与官方 Telegram 包名相同但签名不同，首次安装需卸载官方版。

> 注意：fork 仓库首次使用时需要在 **Actions** 页面启用 workflow（或执行一次
> `gh api -X PUT repos/<owner>/<repo>/actions/permissions -f enabled=true`），
> 否则推送标签不会触发构建。

## 7. 可复现性说明

- 仓库不包含 `artifacts/`（APK 产物）与构建缓存；构建产物由源码 + 固定工具链重新生成。
- 上游版本固定为 13.1.1（`3de37c8`），升级流程见 `docs/UPSTREAM-SYNC.md`。
