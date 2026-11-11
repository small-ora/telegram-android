#!/usr/bin/env bash
# 构建 debug APK（包名带 .beta，可与官方版共存）
set -euo pipefail

source "$(dirname "$0")/env.sh"
cd "$REPO_ROOT"

mkdir -p artifacts/logs
LOG="artifacts/logs/build-debug-$(date +%Y%m%d-%H%M%S).log"

echo "==> ./gradlew :TMessagesProj_App:assembleDebug（arm64-v8a）"
echo "==> 日志: $LOG"

set +e
./gradlew :TMessagesProj_App:assembleDebug \
  -Pandroid.injected.build.abi=arm64-v8a \
  -Dorg.gradle.jvmargs=-Xmx4g --max-workers=6 --console=plain 2>&1 | tee "$LOG"
STATUS=${PIPESTATUS[0]}
set -e

if [ "$STATUS" -ne 0 ]; then
  echo "❌ 构建失败（退出码 $STATUS），见 $LOG" >&2
  exit "$STATUS"
fi

grep -q 'BUILD SUCCESSFUL' "$LOG" || { echo "❌ 日志中未见 BUILD SUCCESSFUL" >&2; exit 1; }
echo "✅ 构建成功；APK："
find TMessagesProj_App/build/outputs -name '*.apk' -newermt '-2 hours' -print -exec ls -lh {} \; 2>/dev/null || true
