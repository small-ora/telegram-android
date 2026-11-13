#!/usr/bin/env bash
# 构建 debug APK（包名带 .beta，可与官方版共存）
set -euo pipefail

source "$(dirname "$0")/env.sh"
cd "$REPO_ROOT"

mkdir -p artifacts/logs
LOG="artifacts/logs/build-debug-$(date +%Y%m%d-%H%M%S).log"

echo "==> ./gradlew :TMessagesProj_App:assembleDebug（arm64-v8a，非 testOnly）"
echo "==> 日志: $LOG"

set +e
# 同 build-release.sh：显式关闭 AGP 注入构建带来的 android:testOnly=true，
# 否则手机端无法直接安装（只能 adb install -t）。
./gradlew :TMessagesProj_App:assembleDebug \
  -Pandroid.injected.build.abi=arm64-v8a \
  -Pandroid.injected.testOnly=false \
  -Dorg.gradle.jvmargs=-Xmx4g --max-workers=6 --console=plain 2>&1 | tee "$LOG"
STATUS=${PIPESTATUS[0]}
set -e

if [ "$STATUS" -ne 0 ]; then
  echo "❌ 构建失败（退出码 $STATUS），见 $LOG" >&2
  exit "$STATUS"
fi

grep -q 'BUILD SUCCESSFUL' "$LOG" || { echo "❌ 日志中未见 BUILD SUCCESSFUL" >&2; exit 1; }
# 安装门禁（fail-closed）：debug 包同样不能被标记 testOnly，否则手机端无法直接安装
AAPT2="$(ls -d "$ANDROID_HOME"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -1)"
if [ -z "$AAPT2" ] || [ ! -x "$AAPT2" ]; then
  echo "❌ 未找到 aapt2（ANDROID_HOME=$ANDROID_HOME），无法校验安装包" >&2
  exit 1
fi
APK="$(find TMessagesProj_App/build/outputs/apk -path '*afat/debug/*.apk' | sort | head -1)"
if [ -z "$APK" ]; then
  echo "❌ 未找到 afat/debug APK，无法校验安装包" >&2
  exit 1
fi
if "$AAPT2" dump xmltree --file AndroidManifest.xml "$APK" | grep -qE 'testOnly\(0x[0-9a-f]+\)=true'; then
  echo "❌ APK 含 android:testOnly=true，手机端无法直接安装（检查 -Pandroid.injected.testOnly=false）" >&2
  exit 1
fi
echo "✅ 清单无 testOnly，可直接在手机上安装：$APK"

echo "✅ 构建成功；APK："
find TMessagesProj_App/build/outputs TMessagesProj_App/build/intermediates/apk \
  -name '*.apk' -mmin -120 -print -exec ls -lh {} \; 2>/dev/null || true
