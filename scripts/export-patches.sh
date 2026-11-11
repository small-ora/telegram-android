#!/usr/bin/env bash
# 导出本分支的代码补丁序列到 patches/（用于 rebase 冲突过大时手工重放）
# 用法：./scripts/export-patches.sh [基线 ref]
set -euo pipefail

cd "$(dirname "$0")/.."

if [ $# -ge 1 ]; then
  BASE="$1"
elif git remote get-url upstream >/dev/null 2>&1; then
  BASE="$(git merge-base HEAD upstream/master)"
else
  BASE="$(git merge-base HEAD master)"
fi

CODEMAP=(
  TMessagesProj TMessagesProj_App TMessagesProj_AppHockeyApp
  TMessagesProj_AppHuawei TMessagesProj_AppStandalone TMessagesProj_AppTests
  TMessagesProj_Modules build.gradle settings.gradle gradle.properties gradle
)

mkdir -p patches
rm -f patches/*.patch

git format-patch --output-directory patches "$BASE..HEAD" -- "${CODEMAP[@]}"

COUNT=$(find patches -name '*.patch' | wc -l)
echo "==> 已导出 $COUNT 个代码补丁到 patches/（基线：$BASE）"
ls -1 patches/*.patch
