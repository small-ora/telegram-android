# 仓库合并与整理记录（2026-11-11）

> 目的：把原来的「代码目录 `tg-client-code` + 文档目录」合并成一个统一仓库，整理文档与工程结构，
> 为上传 GitHub、后续同步官方版本做准备。
> 结论：**已完成并通过自检**（构建退出码 0、自检通过、链接检查 0 断链）。GitHub 上传待用户提供授权方式后执行。

## 1. 迁移前状态与安全快照

| 项 | 值 |
|---|---|
| 迁移前代码目录 | `/root/tg-client-code/telegram-src`（分支 `feat/no-sms-login-no-ads`，HEAD `1437581`） |
| 迁移前 HEAD | `14375818b904221bfd7b4682b42386013fe8feac` |
| 迁移前快照 | `/root/pre-restructure-20261111/docs-and-meta.tgz`（sha256 `ca7be1ebe4ca63987329836b4a8c577373422817a8a44c9d3e19a477eff17ca`） |
| 快照内容 | `docs/`、`backup-20261102/`、`artifacts/SHA256SUMS`、`artifacts/runlogs/` + `INFO.txt`（git 分支/HEAD/子模块状态） |
| 代码可回滚性 | 所有代码改动均已提交（`3de37c8..1437581`），`git status` 迁移前为空 |

## 2. 结构变化

迁移前：

```
/root/tg-client-code/
├── docs/                  # 项目文档
├── artifacts/             # APK 等产物
├── backup-20261102/       # 备份
└── telegram-src/          # 官方源码 git 仓库（分支 feat/no-sms-login-no-ads）
```

迁移后（**当前工作区 = 仓库根 = GitHub 仓库根**）：

```
/root/tg-client-docs/
├── docs/                  # 全部文档（索引见 docs/README.md）
│   ├── spec/              # SPEC v1 历史版、v2.1 冻结版、v2.2 提案
│   ├── recon/             # 环境勘察、源码勘察
│   ├── evidence/          # 编译/真机证据、日志、截图、SPEC 冻结记录
│   ├── BUILD.md           # 构建指南
│   ├── UPSTREAM-SYNC.md   # 官方升级同步流程
│   ├── MODIFICATIONS.md   # 相对官方的修改记录（GPL）
│   ├── PLAN.md / ACCEPTANCE.md
│   └── upstream-README.md # 上游 README 存档
├── scripts/               # 构建 / 同步 / 补丁导出 / 自检
├── patches/               # 4 个代码补丁（相对 13.1.1）
├── tools/probe/           # Telethon 探针脚本
├── TMessagesProj*/ ...    # 官方源码（git 工作树，分支 feat/no-sms-login-no-ads）
└── artifacts/、backup-*/  # 本地文件，已 gitignore
```

整理动作：

1. 源码目录整体上移为仓库根（同一文件系统 rename，`.git` / 子模块 / 构建缓存均可继续使用）；
2. 文档统一到 `docs/`，按 spec / recon / evidence / 维护指南归类；
3. 删除 `.ai/no-sms-login-no-ads/`（内容与 `docs/` 重复，其中 SPEC 与冻结版 sha256 完全一致）；
4. SPEC 去重：保留 `docs/spec/SPEC-v2.1-frozen.md`，冻结记录 `docs/evidence/frozen/SPEC_BASE.txt` 指向该文件；
5. 探针脚本移入 `tools/probe/`；**`.session` 登录态文件与 `.venv/` 移出工作树**（会话文件移至 `backup-20261102/spike-sessions/`，永不入库）；
6. 根 `README.md` 重写为 fork 说明；上游原 README 存档为 `docs/upstream-README.md`；
7. 新增 `scripts/`（构建、同步官方、导出补丁、自检）与 `patches/`（4 个代码补丁）；
8. `.gitignore` 排除 `artifacts/`、`backup-*/`、`*.apk`、`*.session`、`.venv/`、`__pycache__/`。

## 3. 验证证据

### 3.1 合并后构建（验证目录迁移未破坏构建）

```text
命令: ./scripts/build-debug.sh
日志: artifacts/logs/build-debug-20261111-171549.log
结果: BUILD SUCCESSFUL in 5m 15s（退出码 0，301 tasks executed）

产物: TMessagesProj_App/build/intermediates/apk/afat/debug/app.apk
sha256: e352e9e094843b31c23f297eb82c285a3e69af055c9ff0c167bf91348dae48b0
```

### 3.2 仓库自检（`./scripts/repo-check.sh`，退出码 0）

```text
✅ 当前分支：feat/no-sms-login-no-ads
✅ 工作区干净
✅ 子模块已初始化
✅ 无敏感/产物文件被跟踪
✅ 本仓库维护的文档/脚本/补丁中无 >5MB 文件
✅ docs/scripts/tools 中未发现疑似密钥
== 自检通过 ==
```

### 3.3 其他检查

| 检查 | 结果 |
|---|---|
| 文档相对链接（`docs/`、根 README、`patches/`、`tools/`） | 断链 0 |
| 密钥/会话扫描（`ghp_`、`github_pat_`、私钥、`.session`） | 未发现 |
| 迁移前快照 sha256 记录 | `ca7be1eb…`（见 §1） |
| APK 校验和 | 见 `docs/evidence/artifacts-SHA256SUMS.txt`（产物不入库，仅存档校验和） |

## 4. 合并后的提交记录（`git log --oneline`）

```text
73fb5e0 fix(scripts): 构建成功后正确定位 APK（outputs + intermediates 两处）
f3fe4cb fix(scripts): 修正 repo-check 的误报（上游预编译大文件、自匹配密钥模式）
36011c4 chore(repo): 新增构建/同步脚本、补丁序列与本地文件忽略规则
2001130 docs: 合并 tg-client-code 工作区并重组文档结构
1437581 fix(login): 修正二维码页尺寸（dp 二次换算）+ 扫码流程增加错误日志
de96d77 feat(login): 新设备扫码登录（G1-a）
bc9e3c6 feat(ads): 关闭视频/图片查看器贴片广告（VideoAds）
ca4085c feat(ads): 关闭频道内/bot 内赞助消息与搜索推荐频道（G2）
ecd0b17 chore(spec): freeze SPEC v2.1 as baseline
3de37c8 update to 13.1.1 (7237)   ← 官方上游基线
```

## 5. 回滚方法

```bash
# 恢复文档/产物到迁移前（代码仓库不受影响）
mkdir -p /tmp/rollback && tar xzf /root/pre-restructure-20261111/docs-and-meta.tgz -C /tmp/rollback
# 或按文档结构恢复：/tmp/rollback/docs → 仓库根

# 回滚文档/脚本提交（保留代码改动）
git reset --hard 1437581
```

## 6. 未完成 / 后续

- GitHub 仓库创建与推送：✅ 已完成，见 `docs/evidence/GITHUB-PUBLISH-20261111.md`（public fork，CI 自动构建并发布 Release）；
- 官方已发布 13.2.1（`7be672e`），本仓库基线仍为已验证的 13.1.1；升级按 `docs/UPSTREAM-SYNC.md` 执行，
  需要重新构建 + 真机冒烟后再作为日用包；
- APK 发布：✅ 已由 GitHub Actions 自动构建并发布到 Releases（v13.1.1）。
