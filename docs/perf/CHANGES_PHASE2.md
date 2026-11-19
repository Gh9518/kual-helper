# 阶段 2 逻辑改动清单（供阶段 4 分组提交）

> 当前 `/workspace` 非 git 工作树，历史通过 GitHub API 发布。本清单记录「一个逻辑改动 =
> 一个 commit」的分组，阶段 4 clone 线上仓库后按此顺序提交。
> 硬约束遵循情况：未新增依赖；未改公开 API / CLI 参数 / 配置文件格式 / 目录结构契约；
> 一个文件能解决的不碰第二个；超范围项已记入 `docs/tech-debt.md`。

## Commit 1 — `fix(google-translate)`: 异常退出与更新失败不再把系统分区留在 rw

**为什么**：`fix_google_translate.sh` 用 `mntroot rw` 改 `/etc/hosts`，但 EXIT trap 只做
nolock/临时文件清理，不恢复 ro。信号中断或提前 `exit 0` 会让系统分区停留可写。
同时 `clean_hosts` 的 `grep || : > $TMP` 在源不可读时可能把空文件 mv 覆盖 hosts。

**改了哪些文件**：`helper/bin/fix-google-translate/fix_google_translate.sh`
- 新增 `GT_RW_HELD` 标志，`_gt_cleanup` 据此恢复 `mntroot ro`（覆盖正常/信号退出）。
- 三处 `mntroot rw/ro` 改为同步维护 `GT_RW_HELD`。
- `clean_hosts` 用带 PID 临时名；仅当源文件可读且临时文件确实生成时才 mv，否则 return 1、不覆盖。

**验证**：桩测 3 项通过（rw-held 恢复 ro / 正常过滤 / 源缺失不覆盖 hosts）。

## Commit 2 — `fix(block-ota)`: 备份/恢复 OTA 失败时中止并恢复只读

**为什么**：`rename.sh`/`restore.sh` 的 `mv` 无失败检查，mv 失败仍继续写占位脚本或提示成功，
可能让 `otaupd/otav3` 与其备份处于不一致状态，导致以后无法恢复。

**改了哪些文件**：
- `helper/bin/block-ota/rename.sh`：`mv otaupd→.bck` 与 `mv otav3→.bck` 失败则 `mntroot ro` +
  `msg_fail` + 退出，不再写占位脚本。
- `helper/bin/block-ota/restore.sh`：恢复的两个 `mv` 失败同样中止并恢复只读。

**验证**：桩测 2 项通过（mv 失败时均 `rw→ro` 且给出可读错误）。

## Commit 3 — `docs(readme)`: 补充最常见 3 个用法与回滚方案

**为什么**：阶段 2 易用性要求「最常见 3 个用法 + 出问题怎么回滚」。原 README 只有菜单结构、
故障排查日志结论，没有集中的「用法/回滚」入口。

**改了哪些文件**：`README.md`（新增第十四节，不改动任何功能描述）。

## 文档类（并入上述 commit 或单独 docs commit）

- `docs/perf/baseline.json`：阶段 0 基线（未改源码，新增）。
- `docs/perf/measure.py`：可复用采集器（阶段 0/3 口径一致，新增）。
- `docs/research/REFERENCE.md`：阶段 1 调研（新增）。
- `docs/tech-debt.md`：本轮超范围项（新增）。
- `docs/perf/AFTER.md`：阶段 3 生成（待）。
