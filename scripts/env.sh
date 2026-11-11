#!/usr/bin/env bash
# 统一设置构建环境变量；用法：source scripts/env.sh
# 可用环境变量覆盖：JAVA_HOME / ANDROID_HOME / ANDROID_SDK_ROOT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"
export ANDROID_HOME="${ANDROID_HOME:-/opt/android-sdk}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"

if [ ! -d "$JAVA_HOME" ]; then
  echo "警告: JAVA_HOME 不存在: $JAVA_HOME（请安装 JDK 17 或手动指定）" >&2
fi
if [ ! -d "$ANDROID_HOME" ]; then
  echo "警告: ANDROID_HOME 不存在: $ANDROID_HOME（请安装 Android SDK 36 或手动指定）" >&2
fi
if [ ! -f "$REPO_ROOT/local.properties" ]; then
  echo "提示: 缺少 local.properties，首次构建前执行：" >&2
  echo "      echo 'sdk.dir=$ANDROID_HOME' > \"$REPO_ROOT/local.properties\"" >&2
fi
