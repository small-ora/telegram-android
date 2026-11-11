# S6 Release 构建结果（2026-11-02）

> 结论：**✅ `assembleRelease` 一条命令产出 arm64-v8a release APK**（AC-8 的构建部分已满足）。
> 注意：release 包名是 `org.telegram.messenger`（与官方版相同），装它需要先卸载官方版；日常测试建议用 debug `.beta` 包（可与官方版共存）。

## 命令与结果

```bash
cd <repo-root>
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ANDROID_HOME=/opt/android-sdk ANDROID_SDK_ROOT=/opt/android-sdk
./gradlew :TMessagesProj_App:assembleRelease \
  -Pandroid.injected.build.abi=arm64-v8a \
  -Dorg.gradle.jvmargs=-Xmx4g --max-workers=6 --console=plain
```

| 项 | 值 |
|---|---|
| 退出码 | **0** |
| 耗时 | `BUILD SUCCESSFUL in 12m 36s`（385 tasks: 381 executed / 4 up-to-date；release 首次编译 native + R8） |
| 日志 | `docs/evidence/logs/build-S6-release-20261102-095653.log` |
| APK | `artifacts/tg-client-S6-arm64-release.apk`（40,661,527 bytes ≈ 38.8 MiB） |
| sha256 | `6883a2527f99d9b52299adc1e88a195b9541efbd2176936bd2c1ec70626ef846` |
| applicationId | `org.telegram.messenger`（**与官方版冲突：需先卸载官方版才能装**） |
| versionName | 13.1.1（versionCode 7237） |
| 签名 | fork 自带的 `TMessagesProj/config/release.keystore`（CN=Android Developer, OU=Telegram；**不是官方签名**） |
| 主 native lib | `lib/arm64-v8a/libtmessages.49.so`（22 MB，R8 + 符号裁剪后比 debug 小很多） |

## 与 debug 包的区别（选择建议）

| 包 | 路径 | applicationId | 能否与官方版共存 | 适用 |
|---|---|---|---|---|
| debug | `artifacts/tg-client-S4-arm64-debug.apk` | `org.telegram.messenger.beta` | ✅ 可以 | **日常/验收测试首选**（有日志、可 side-by-side） |
| release | `artifacts/tg-client-S6-arm64-release.apk` | `org.telegram.messenger` | ❌ 需先卸载官方版 | 最终自用装机 |

## 未覆盖 / 注意

1. **运行期未验证**：release 包同样没在真机跑过（无设备）。R8 已开（`minifyEnabled`），理论上被反射/JS 桥引用的类有混淆风险 —— 官方 proguard 规则已覆盖，但**真机验证时建议先用 debug 包排错、release 包做最终回归**。
2. **签名不可升级官方版**：用 fork keystore 签名，与官方签名不同，不能覆盖安装官方版（必须卸载）。
3. AC-8 还要求「记录 JDK/NDK/Gradle 版本」——版本清单见 `evidence/M1-build-result.md` §2。
