#!/usr/bin/env bash
# 构建 release APK（沿用仓库自带 TMessagesProj/config/release.keystore 签名）
set -euo pipefail

source "$(dirname "$0")/env.sh"
cd "$REPO_ROOT"

mkdir -p artifacts/logs
LOG="artifacts/logs/build-release-$(date +%Y%m%d-%H%M%S).log"

echo "==> ./gradlew :TMessagesProj_App:assembleAfatRelease（arm64-v8a，非 testOnly）"
echo "==> 日志: $LOG"

set +e
# -Pandroid.injected.build.abi 是 AGP 的 IDE 注入参数，副作用是把 APK 标记成
# android:testOnly=true（手机端直接点安装会失败）；必须显式 testOnly=false 关闭。
./gradlew :TMessagesProj_App:assembleAfatRelease \
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

# 安装门禁（fail-closed）：确认 APK 没有被标记 testOnly，否则手机端点击安装会静默失败
AAPT2="$(ls -d "$ANDROID_HOME"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -1)"
if [ -z "$AAPT2" ] || [ ! -x "$AAPT2" ]; then
  echo "❌ 未找到 aapt2（ANDROID_HOME=$ANDROID_HOME），无法校验安装包" >&2
  exit 1
fi
APK="$(find TMessagesProj_App/build/outputs/apk -path '*afat/release/*.apk' | sort | head -1)"
if [ -z "$APK" ]; then
  echo "❌ 未找到 afat/release APK，无法校验安装包" >&2
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
