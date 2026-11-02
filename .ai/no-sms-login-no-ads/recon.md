# 环境勘察（Phase 0）

勘察时间：2026-11-01
勘察主机：`pve-debian12`（Debian GNU/Linux 12 bookworm，x86_64）
勘察方式：只读命令；未安装任何依赖，未修改系统。

## 1. 硬件与系统

| 项 | 实测值 | 判定 |
|---|---|---|
| OS | Debian 12 (bookworm), kernel 6.1.0-30-amd64 | ✅ 可构建 Android |
| CPU | 8 核 | ✅ 够用（Gradle 并行可开 8） |
| 内存 | 11 GiB（可用 7.2 GiB） | ⚠️ 编译大型 Java 工程偏紧，建议 `org.gradle.jvmargs=-Xmx4g` 并考虑加 swap |
| 磁盘 | `/` 62G，已用 19G，**可用 41G** | ⚠️ 官方客户端源码 + NDK + 构建产物约需 15–25G，够但余量不大 |

## 2. 工具链现状

| 工具 | 状态 | 备注 |
|---|---|---|
| git | ✅ 2.39.5 | 可用 |
| python3 | ✅ 3.11.2 | 可用于 Spike |
| pip3 | ✅ 23.0.1 | 系统 pip 受 PEP 668 限制，需建 venv |
| node | ✅ v25.5.0 | 本项目不需要 |
| **java / javac** | ❌ 无 | **必须安装 JDK 17**（AGP 要求） |
| **gradle** | ❌ 无 | 用 Gradle Wrapper 即可，无需系统安装 |
| **android SDK / sdkmanager** | ❌ 无 | **必须安装** cmdline-tools + platform-tools + build-tools |
| **android NDK** | ❌ 无 | **必须安装**（TDLib 原生库编译需要） |
| **adb** | ❌ 无 | 真机装包/日志需要 |
| cmake / ninja | ❌ 无 | NDK 自带 cmake，ninja 需要 |

环境变量：`ANDROID_HOME` / `ANDROID_SDK_ROOT` / `JAVA_HOME` 均未设置。

## 3. 网络连通性（实测，2026-11-01）

| 目标 | 结果 | 说明 |
|---|---|---|
| `149.154.167.51:443` | ✅ TCP 可达 | Telegram DC4 |
| `91.108.56.130:443` | ✅ TCP 可达 | Telegram DC5 |
| `my.telegram.org:443` | ✅ TCP 可达 | 可注册 api_id |
| `dl.google.com:443` | ✅ TCP 可达 | Android SDK / Maven 依赖可拉 |
| `repo.maven.apache.org:443` | ✅ TCP 可达 | Maven Central 可拉 |
| `services.gradle.org:443` | ✅ TCP 可达 | Gradle 发行版可下 |

未设置 HTTP(S) 代理。**结论：Spike 与构建都可以在本机完成，无需额外网络配置。**

## 4. 验证命令（本项目的等价命令定义）

由于代码仓库尚未创建（将要 fork 官方源码），以下为本阶段已确定的命令；仓库落地后写入其 `AGENTS.md`。

| 类别 | 当前定义 |
|---|---|
| `VALIDATION_QUICK` | Spike 阶段：`python3 spike-probe/probe_sentcode.py` 退出码 0 且输出 `RESULT:` 行 |
| `VALIDATION_FULL` | 构建阶段：`./gradlew :TMessagesProj_App:assembleRelease` 退出码 0 且产出 APK |
| `DIFF_CMD` | 有 git 后：`git diff <BASE>..HEAD` |
| `CHECKPOINT` | 有 git 后：本地提交，一主题一 commit |
| `ENFORCEMENT` | `prompt-only`（无 CI、无 pre-commit；靠流程自觉） |
| `CI_REQUIRED` | 无（本项目仅自用，不接 CI） |

## 5. 红线（本项目适用）

按 `ai-dev-workflow` 分级，本项目涉及：

1. **鉴权/登录链路**（TDLib `auth.*` 调用、验证码处理、2FA）→ **L3 红线**，改动需人确认。
2. **密钥**：`api_id` / `api_hash` → 不写入仓库明文、不提交、不写进文档正文；运行期从本地配置文件读取且加入 `.gitignore`。
3. **第三方代码**：fork 官方 GPLv2 源码，**不引入来源不明的二进制/预编译库**。
4. **不可逆操作**：不向真实账号发送消息、不改他人账号、不批量登录。

## 6. 待办的环境准备清单（M1 里程碑）

```bash
# 1. JDK 17
apt-get install -y openjdk-17-jdk

# 2. Android cmdline-tools + SDK
mkdir -p /opt/android-sdk/cmdline-tools
# 下载 commandlinetools-linux-*.zip → 解压为 /opt/android-sdk/cmdline-tools/latest
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

# 3. NDK（版本随官方源码要求，当前主流 25c/26b）
sdkmanager "ndk;26.1.10909125"

# 4. 环境变量写入 ~/.bashrc
export ANDROID_HOME=/opt/android-sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
```

以上命令**尚未执行**，将在 M1 阶段经你确认后执行。
