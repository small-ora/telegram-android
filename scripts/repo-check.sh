#!/usr/bin/env bash
# 推送/提交前自检：分支、工作区、子模块、敏感文件、大文件、疑似密钥
set -uo pipefail

cd "$(dirname "$0")/.."
FAIL=0

ok()  { echo "✅ $1"; }
bad() { echo "❌ $1"; FAIL=1; }

BRANCH="$(git branch --show-current 2>/dev/null || echo '<detached>')"
if [ "$BRANCH" = "feat/no-sms-login-no-ads" ]; then
  ok "当前分支：$BRANCH"
else
  bad "当前分支为 $BRANCH，不是 feat/no-sms-login-no-ads（仅提示，不影响自检）"
fi

if [ -z "$(git status --porcelain)" ]; then ok "工作区干净"; else bad "工作区有未提交改动"; fi

if git submodule status | grep -q '^-'; then
  bad "存在未初始化子模块（git submodule update --init --recursive）"
else
  ok "子模块已初始化"
fi

TRACKED_BAD="$(git ls-files | grep -Ei '(^|/)\.venv/|\.session$|\.pyc$|__pycache__|(^|/)artifacts/|(^|/)backup-' || true)"
if [ -z "$TRACKED_BAD" ]; then
  ok "无敏感/产物文件被跟踪"
else
  bad "以下文件不应被跟踪："; echo "$TRACKED_BAD" | head -20
fi

BIG="$(git ls-files -z -- docs scripts tools patches | xargs -0 -r du -k 2>/dev/null | awk '$1 > 5120 {print $2}' | head -10)"
if [ -z "$BIG" ]; then
  ok "本仓库维护的文档/脚本/补丁中无 >5MB 文件"
else
  bad "发现 >5MB 文件（docs/scripts/tools/patches）："; echo "$BIG"
fi

LEAK="$(grep -rInE --exclude=repo-check.sh 'ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}|-----BEGIN (RSA|OPENSSH|EC) PRIVATE KEY-----' docs scripts tools 2>/dev/null || true)"
if [ -z "$LEAK" ]; then
  ok "docs/scripts/tools 中未发现疑似密钥"
else
  bad "疑似密钥（请立即移除）："; echo "$LEAK" | head -10
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "== 自检通过 =="
else
  echo "== 自检未通过，请按上面提示处理 =="
  exit 1
fi
