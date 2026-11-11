# M1 首次编译基线结果（2026-11-02）

> 结论：**✅ 基线编译通过**（BUILD SUCCESSFUL，退出码 0），产出可装机的 arm64-v8a debug APK。
> 这是 PLAN.md 中 S1 的完成证据，也是人工门禁 **G-2** 的输入。

## 1. 命令与结果

```bash
cd <repo-root>
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ANDROID_HOME=/opt/android-sdk ANDROID_SDK_ROOT=/opt/android-sdk
./gradlew :TMessagesProj_App:assembleDebug \
  -Pandroid.injected.build.abi=arm64-v8a \
  -Dorg.gradle.jvmargs=-Xmx4g --max-workers=6 --console=plain
```

| 项 | 值 |
|---|---|
| 执行时间 | 2026-11-02 09:21:57 → 09:28:29 (+08:00) |
| 退出码 | **0** |
| 构建耗时 | `BUILD SUCCESSFUL in 6m 32s`（301 tasks: 158 executed / 143 up-to-date，上一次中断的产物被复用） |
| 日志 | `docs/evidence/logs/build-M1-20261102-092157.log`（119 KB，未经删改） |
| 产物 | `TMessagesProj_App/build/intermediates/apk/afat/debug/app.apk`（67,425,565 bytes ≈ 64.3 MiB） |
| variant | `afatDebug`（Telegram 默认 flavor） |
| 主 native lib | `lib/arm64-v8a/libtmessages.49.so`（43 MB） |

## 2. 工具链实测版本

| 组件 | 版本 |
|---|---|
| OS | Debian 12 (bookworm), kernel 6.1, x86_64, 8 核 / 11 GiB |
| JDK | OpenJDK 17.0.21 (Debian 17.0.21+9) |
| Gradle | 8.13（wrapper 自带，已缓存于 `~/.gradle/wrapper`） |
| AGP | 8.13.2 |
| compileSdk / targetSdk | 36 / 36 |
| build-tools | 36.0.0 |
| NDK | 27.2.12479018（`/opt/android-sdk/ndk`） |
| CMake | 3.22.1（SDK 自带） |
| 磁盘占用 | 构建后 `/` 已用 30G / 62G（余 29G） |

## 3. 关键日志尾部

```
> Task :TMessagesProj_App:packageAfatDebug
> Task :TMessagesProj_App:createAfatDebugApkListingFileRedirect
> Task :TMessagesProj_App:assembleAfatDebug
> Task :TMessagesProj_App:assembleDebug
BUILD SUCCESSFUL in 6m 32s
301 actionable tasks: 158 executed, 143 up-to-date
```

构建期只有告警（D8 对 `play-services-recaptchabase` 的 companion object 提示、Gradle 9 弃用提示），无 `error:`、无编译失败。

## 4. 未覆盖项 / 注意

1. **未接真机**：`adb devices` 为空，APK 尚未安装验证。真机验证属 M4（AC-2~AC-7），需你提供设备或自行 sideload。
2. **debug variant**：本步只验证「基线能编过」。AC-8 要求的是 `assembleRelease` 一条命令可复现，留到 S6。
3. **APK ABI**：本次用 `-Pandroid.injected.build.abi=arm64-v8a` 限定主库，只适合 arm64 真机；其余 ABI 仅有 language_id jni 占位。
4. 构建产物与 `.gradle/`、`.cxx/`、`build/` 均已被 `.gitignore` 覆盖，`git status` 干净。

## 5. 对后续步骤的意义

- S1 的「基线绿」判据（`assembleDebug` 退出码 0）**已满足**；
- 后续 S3/S4 的验证命令沿用同一命令（增量构建预计 1–3 分钟）；
- G-2 门禁：编译已绿，可以进入 M2 改造（S3 去广告 → S4 扫码登录）。
