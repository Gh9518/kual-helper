# 更新说明 / Changelog

## v1.8.0 — 2026-11-06

**修复 / Fixed（全部功能失效）**
- 回到最初上传的原始插件包逐项核对，定位「每一项点击后都无反应」的共性根因：菜单用相对
  `./bin/...` 调用脚本，脚本内又以 `. ./bin/config.sh` / `. ./bin/msg.sh` 加载依赖，
  隐含假设 KUAL 执行时的工作目录就是插件目录，并依赖可执行位与 shebang。
- `menu.json`：17 个 `action` 全部改为绝对路径 + 显式 `/bin/sh`
  （`/bin/sh /mnt/us/extensions/helper/bin/...`）；删除全部 `checked` 与 `internal`，
  保留 `status:false`。删除 `checked` 后，屏保 / 商店不再出现「同时选中」的假状态。
- 全部 14 个 `.sh` 加入 `KUAL_HOME` 自定位（由 `$0` 真实路径向上查找 `config.xml`），
  `config.sh` / `msg.sh` / Python 入口一律改为 `$KUAL_HOME/bin/...` 绝对路径；
  依赖不可读时定义最小反馈函数，避免 POSIX `sh` 因 `.` 失败直接终止。
- 去掉非 POSIX 写法（`source` / `&>` / `==` / `local`）；`updatewait` 日志改写到
  `/dev/null`；`fix-google-translate.sh` 补 `grep` / `sed` / `curl` 命令兜底。
- 修复 `do.sh` 去 `local` 引入的回归：原版 `local verb=... btnpath=... bak` 去掉 `local`
  后裸 `bak` 被当命令执行，前置赋值只在该命令环境生效，`btnpath` 恒为空，导致「替换商店 /
  恢复商店」必然报 `Store button file not found (unsupported firmware)`。已改为逐行赋值。

**校验 / Verified**
- 静态：`menu.json` 合法；17 个动作全部绝对路径 + 显式 `/bin/sh`；无 `checked` / `internal`；
  全部 `.sh` 与 `updatewait` 通过 `sh -n`，9 个 `.py` 通过编译检查，无 BOM / CRLF。
- 真机语义桩测 **17/17**：`cwd='/'`、脚本 `644` 无可执行位、不注入
  `KUAL_HOME` / `KINDLE_PATH` / `KUAL_EIPS`、系统命令用 mock；17 个动作全部出现
  `Waiting...` 与 `Done:` 且无 `Failed:`，并逐项断言副作用（屏保 1/0、商店改写与还原、
  日志删除、hosts 写入最快 IP、OTA 改名与还原、backdoorlock 劫持与还原、更新包删除、
  更新检查执行）。

**文档 / Docs**
- `config.xml` / `VERSION` 升至 v1.8.0；`README.md` 新增「执行链修复与本轮校验」一节，
  `RELEASE_NOTES.md` 中英双语同步；`extensions.zip` 与 `helper.zip` 重新打包。

---

## v1.7.0 — 2026-11-05

**新增 / Added**
- 一级菜单与 KUAL 状态文本全部改回中文：系统工具 / 修复失效 / 屏蔽更新 / 检查更新。
- 新增 `bin/msg.sh` 统一屏幕反馈：每个动作点击后先显示 `Waiting...`，结束时显示
  `Done: ...` 或 `Failed: ...`；清理三项、修复四项、屏蔽更新五项、检查更新全部接入。
- 反馈带具体结果：清理类显示删除的 SDR 文件夹 / 截图 / 日志数量与释放空间、删除的更新文件
  个数；修复谷歌显示选中的最快 IP 与耗时；检查更新逐行显示版本状态。

**变更 / Changed**
- 「禁用屏保 / 允许屏保 / 替换商店 / 恢复商店」恢复为四个常驻独立菜单（原始 helper 与
  KUAL-add-ons 方案）：删除 `.screensaver_disabled` 状态文件与全部 `if` 互斥条件，菜单不再因
  系统文件缺失或重启后状态不同而隐藏；屏保脚本恢复为直接 `lipc-set-prop` 调用。
- 商店脚本补上失败分支的 `mntroot ro`，并在不支持的固件上明确提示，避免静默无反应。
- 屏幕提示统一使用简短英文（Kindle `eips` 使用固化 ASCII 字体，中文会显示为方块）；
  菜单与 KUAL 状态栏仍为中文。

**校验 / Verified**
- 17 个菜单动作逐一桩测：均出现 `Waiting...` 与 `Done:` / `Failed:` 提示；
- 屏保 `lipc-set-prop ... preventScreenSaver 1/0` 调用正确；商店替换 / 恢复真实改写
  `search_bar.js` 并能完整还原、备份文件正确清理；
- 全部 `.sh` 通过 `sh -n`，全部 `.py` 通过编译检查，`menu.json` 结构合法。

---

## v1.6.0（首次正式发布 / First public release）— 2026-11-05

**新增 / Added**
- 单插件整合：原 6 个 KUAL 扩展合并为 `helper`，4 个英文一级菜单
  （System Tools / Repair / Block Updates / Check Update）。
- 封面修复支持 EPUB、PDF，联网多源补齐（仅无封面的书）。
- 修复谷歌：从 GitHub 自动取 IP、逐个测速、写 hosts（多源 + 兜底）。
- 清理日志：清理所有日志与 Kindle 崩溃转储（4 类 + 同类变体）。
- GitHub 更新器：检查版本、有更新才下载安装。
- 屏保 / 商店改为互斥开关，菜单更精简；系统工具三个清理项归到末尾。

**修复 / Fixed**
- `FixCover.handle()` 空路径 `TypeError`、可变默认参数、Linux 根目录探测失效。
- DB 模式修复成功却误报「无需修复」；`unlink(True)` 兼容 Python 3.5+。
- 修复谷歌重复运行导致 hosts 累积；curl 缺失判断逻辑。
- 屏蔽/恢复更新的幂等保护（防止覆盖 OTA 备份导致无法恢复）。
- SDR 清理：后缀识别、递归子目录、无效逻辑移除。
- 更新器 zip-slip 防护；backdoorlock 残留日志写入清理。
- 更新器匿名 API 被限流（HTTP 403）时改用 `/releases/latest` 网页重定向兜底取版本、
  按固定规则拼下载地址；下载失败自动重试一次，弱网更稳。

**文档 / Docs**
- 新增中英双语发布说明 `RELEASE_NOTES.md`、致谢 `CREDITS.md`、本更新说明。
- `GITHUB_REPO` 指向正式仓库 `Gh9518/kual-helper`。

---

### 整合历程（简表 / Integration history）

| 版本 | 要点 |
|---|---|
| v1.0 | 6 插件梳理；禁更新保留 2 套方案，其余功能并入 `kual-toolbox` 二级菜单；修复联网与「选最快网络」 |
| v1.1 | 封面扩展 EPUB/PDF，新增联网多源封面（Open Library / Google Books / Amazon / 豆瓣） |
| v1.2 | 全部功能收进 4 个二级菜单，新增 GitHub 更新机制 |
| v1.3 | 安装目录改名 `helper`；删「设备信息」；插件更新改为点击即检测 |
| v1.4 | 菜单扁平化、去日志；屏保/商店/清理分项；「修复谷歌」改为 GitHub 自动取 IP |
| v1.5 | 新增「清理日志」 |
| v1.6 | 屏保改互斥开关、清理三项归后、删内置 Install MR、菜单名英文化；本轮代码审查与修复、发布到 GitHub |
| v1.7 | 菜单改回中文；屏保/商店恢复四个独立菜单原方案；新增统一 Waiting / Done / Failed 屏幕反馈 |
| v1.8 | 全功能修复：17 个动作改绝对路径 + 显式 /bin/sh、脚本自定位 KUAL_HOME、删除 checked 勾选；修掉商店 do.sh 去 local 引发的回归 |
