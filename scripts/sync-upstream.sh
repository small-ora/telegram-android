#!/usr/bin/env bash
# 把 feat/no-sms-login-no-ads 分支 rebase 到官方最新版本（默认 upstream/master）
# 用法：./scripts/sync-upstream.sh [目标 ref，默认 upstream/master]
set -euo pipefail

cd "$(dirname "$0")/.."
TARGET="${1:-upstream/master}"
BRANCH="feat/no-sms-login-no-ads"

CURRENT="$(git branch --show-current)"
if [ "$CURRENT" != "$BRANCH" ]; then
  echo "❌ 请在 $BRANCH 分支执行（当前：$CURRENT）" >&2
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "❌ 工作区不干净，请先 commit 或 stash 后再升级" >&2
  git status --short >&2
  exit 1
fi

if ! git remote get-url upstream >/dev/null 2>&1; then
  echo "❌ 缺少 upstream 远端。首次配置见 docs/UPSTREAM-SYNC.md §1" >&2
  exit 1
fi

echo "==> 拉取官方更新"
git fetch upstream --prune

if ! git rev-parse --verify --quiet "$TARGET" >/dev/null; then
  echo "❌ 目标 ref 不存在：$TARGET" >&2
  exit 1
fi

BACKUP="backup/pre-sync-$(date +%Y%m%d-%H%M%S)"
git branch "$BACKUP"
echo "==> 升级前备份分支：$BACKUP"
echo "==> 目标：$TARGET ($(git log -1 --format='%h %s' "$TARGET"))"

if git rebase "$TARGET"; then
  echo
  echo "✅ rebase 完成（$(git rev-list --count "$TARGET"..HEAD) 个本地提交已重放）"
  echo "下一步："
  echo "  1) ./scripts/build-debug.sh"
  echo "  2) 真机冒烟：扫码登录 / 去广告 / 常规收发（见 docs/UPSTREAM-SYNC.md §2.2）"
  echo "  3) 通过后：git push --force-with-lease origin $BRANCH"
else
  echo
  echo "❌ rebase 发生冲突，请处理：" >&2
  echo "  - 解决冲突后：git add <file> && git rebase --continue" >&2
  echo "  - 放弃本次升级：git rebase --abort" >&2
  echo "  - 冲突集中在 LoginActivity.java / strings.xml 时，可改用 patches/ 重放（docs/UPSTREAM-SYNC.md §2.1）" >&2
  exit 1
fi
