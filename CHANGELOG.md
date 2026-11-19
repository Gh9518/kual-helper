# 更新说明 / Changelog

## v1.11.0 — 2026-11-20

**重构 / Refactor（结构与可维护性，功能不变）**
- 新增 `bin/common.sh`：把原先散落在 14 个脚本里、约 20 行/份的「KUAL_HOME 自定位 +
  msg.sh 加载 + 降级函数 + print_log」样板代码**收敛为唯一实现**。公共行为今后只需改一处，
  消除历史上「改一处漏十三处」导致功能集体失效的结构性风险。
- 13 个动作脚本与 `config.sh` 改为统一 source `common.sh`；common.sh 自带幂等哨兵，
  重复 source 安全。已逐行比对：13 个脚本的**主体业务逻辑与上一版完全一致**，
  本次只替换了引导头。
- 引导头在 common.sh 缺失时仍提供最小屏幕反馈降级，主动作不受影响。

**稳定性 / Stability**
- `FixCover._get_isbn()`：`EPUBFile` 未 `close()`，联网补封面遍历大量 EPUB 时会泄漏
  ZipFile 句柄；改为 `try/finally` 确定性关闭（成功与异常路径均覆盖）。
- `FixCover._find_pdf_manual_cover()`：`open().read()` 改用 `with` 关闭文件句柄。
- `FixCover.__del__()`：构造中途失败时 `db_access` 可能未定义，加 `getattr` 防御，
  避免解释器退出时二次抛异常。
- `DualMetaFix.DualMobiMetaFix`：mmap 文件句柄原先从不关闭，且 3 处 early return
  会跳过 flush/close；改为 `try/finally` + 幂等 `close()`，任何路径都释放映射与句柄。
- 更新器 `github_update.py`：下载增加大小上限（JSON 2MB / 更新包 8MB），防止异常响应
  撑爆 Kindle 小内存；下载后校验 zip 合法性、空包、zip-slip、以及必须含 `config.xml`，
  避免错误资产覆盖掉可用插件；错误提示改为可读英文而非 Python traceback。
- `config.sh` 的 `get_python()` 变量加引号，路径含空格时也可正确探测。

**校验 / Verified**
- 引导头探针 **14/14**（每个入口均能产出 Waiting/Done/Failed 三类反馈）；
  13 个脚本主体逻辑逐行 diff 与上一版一致；Python 健壮性桩测 **12/12**；
  v1.10.1 的 mmap OOM 回归 **5/5**（64MB 文件 RSS 增量 0KB）；
  全部 `.sh` 通过 `sh -n`、全部 `.py` 编译通过。

**文档 / Docs**
- `config.xml` / `VERSION` 升至 v1.11.0；`README.md`、`RELEASE_NOTES.md`、
  `CHANGELOG.md` 同步；两个 zip 重新打包。

---

## v1.10.1 — 2026-11-15

**修复 / Fixed（离线「修复封面」被系统杀掉，rc=137）**
- 依据三份真机日志（`run-20261114.log`、`run-20261115.log`、`run-20261115 (1).log`）：
  「修复封面」连续 3 次 `FAIL ... rc=137`（SIGKILL），而同一天的「清理封面」与
  「联网修复封面」均成功。137 是 Kindle **内存不足时 OOM killer** 的信号。
- 根因：`KindleUnpack.Sectionizer` 用 `open().read()` 把**整本** MOBI/AZW3 读进内存，
  逐本遍历全库时峰值内存取决于最大的那本书；一本超大 azw3 即触发 OOM。
  而 `--missing-only` 跳过已有封面的书，恰好没碰到它，所以未复现——与日志现象吻合。
- 改为**只读 mmap 按需映射**：只把实际访问的页计入 RSS，`close()` 立即释放映射；
  `MOBIFile` 构造中途失败时自行清理，`check_file()` 改用上下文管理器关闭句柄。
- 修正 `File.py` 中长期无效的 `bytes`/`str` 比较（FLIS/FCIS/FONT 等资源块与 EOF 标记），
  避免把非图片资源逐块复制出来交给 `imghdr`，进一步减少无谓分配。
- `FixCover.get_ebook_metadata()` 用 `try/finally` 保证每本书解析完即释放，
  并在长循环中每 20 本 `gc.collect()` 一次。

**新增 / Added（可诊断性）**
- `fix_cover.py` 把进度输出到 stdout，由 `fix_cover.sh` 暂存到 `/tmp`；**仅在失败时**
  把最后处理的书名写入运行日志（成功时静默丢弃，不增加日志量、不增加 U 盘写入）。
- `rc=137` 单独识别，屏幕与日志提示 `Killed: low memory (rc=137), run Clean Invalid Covers first`，
  不再笼统报 `Cover tool error`，下次再出问题可直接定位到具体 ebook。

**校验 / Verified**
- 专项桩测 16/16：语法 4 项、64MB 稀疏文件下 RSS 增量 **old 64.0MB → new 0.1MB**、
  section 内容字节一致、map 可重复关闭、空文件降级、构造失败自发释放、
  40 次失败解析 RSS 增长 0.0MB、shell 对 137 的处理与进度捕获。
- 三份真机日志逐行核对：11-14 全部 `OK`；11-15 的 `rc=137` 三次集中在不带参数的全库
  `fix`，`--clean` 与 `--net --missing-only` 正常；「修复谷歌」上午 117/117 不可达、
  当晚找到 1 个可用 IP 并写入 hosts，判定逻辑工作正常，属网络波动非代码故障。

**文档 / Docs**
- `config.xml` / `VERSION` 升至 v1.10.1；`README.md` 新增第十二节；
  `RELEASE_NOTES.md` 中英双语同步；两个 zip 重新打包。

---

## v1.10.0 — 2026-11-07

**查验 / Audit（真机运行日志）**
- 依据 `run-20261107.log` 逐项核对 17 组动作（15 组 `OK`、2 组 `FAIL`、3 行 `INFO`）：
  两处 `FAIL` 为「检查更新」「修复谷歌」，其余均符合预期；幂等分支（商店已替换、OTA 已屏蔽）、
  清理数量、耗时等均正常，也证明 v1.9.0 运行日志与 3 天保留策略工作正常。
  逐项结论见 `README.md` 第十一节。

**修复 / Fixed**
- 「检查更新」：Kindle 老固件 CA 证书过期导致 `CERTIFICATE_VERIFY_FAILED`。`github_update.py`
  先正常校验 TLS，仅证书类错误降级为不校验 CA 重试（API 与网页兜底两路覆盖），日志留提示；
  超时 / 403 不误判；下载包仍受 zip-slip 与 zip 结构校验约束。
- 「修复谷歌」：旧版提示「Testing 117」却由 `MAX_TRIES=18` 只测前 18 个。改为并行分批
  （每批 6 个）覆盖全部候选，判定放宽为 `http_code=200` 且响应含译文（不再依赖固定字段），
  提示与实际一致，失败时明确提示可能是网络阻断。

**新增 / Added（运行时防锁屏）**
- 新增 `bin/nolock.sh`：「修复失效」4 项（修复封面 / 清理封面 / 联网修复封面 / 修复谷歌）
  开始时读取当前 `preventScreenSaver`，仅在原状态为 0 时临时设为 1，结束时恢复 0；
  用户已手动禁用屏保时不改动、不恢复。`trap` 保证异常退出也恢复。其余动作不受影响。
- `preventScreenSaver 1` 是 Kindle 官方「禁止休眠和自动锁屏」开关，附带保持 WiFi 在线的效果，
  可避免数分钟的封面 / 联网修复被休眠冻结或 WiFi 掉线打断。
- 运行日志新增两条 `INFO`：`Screen saver suppressed during action` /
  `Screen saver restored after action`，便于确认防锁屏是否完整执行。

**校验 / Verified**
- 真机语义桩测 17/17；新增断言「修复失效」4 项的防锁屏设置与恢复、其余动作不触发。
- 专项 13/13：保留策略 5 项、用户已禁用屏保时不改写、30 候选中仅第 25 个可用仍成功、
  判定放宽、提示一致、真实证书错误降级且超时 / 403 不误判。
- 全部 `.sh` 通过 `sh -n`，9 个 `.py` 通过编译检查，无 BOM / CRLF。

**文档 / Docs**
- `config.xml` / `VERSION` 升至 v1.10.0；`README.md` 新增「真机日志查验结论」与
  「运行时禁止锁屏」小节；`RELEASE_NOTES.md` 中英双语同步；两个 zip 重新打包。

---

## v1.9.0 — 2026-11-06

**新增 / Added（运行日志）**
- 全部 17 个动作增加结构化运行日志：新增 `bin/log.sh`，`bin/msg.sh` 在输出屏幕提示的同时写入
  `helper/logs/run-YYYYMMDD.log`（按天分文件、UTF-8 追加）。每行含时间、级别
  （`START` / `INFO` / `OK` / `FAIL`）、动作标识与结果文本，可事后确认是否成功。
- 14 个动作脚本的 `msg.sh` 缺失降级分支同步接入日志模块；日志不可写时静默跳过，不影响动作。

**新增 / Added（保留策略与清理推荐）**
- 每次动作启动（KUAL 插件无独立启动时机，动态菜单为静态 `menu.json`）执行一次清理：
  ① 按文件修改时间删除 3 天前及更早的日志（保留最近 3 天）；
  ② 最多保留 10 个日志文件，防设备时钟回拨导致堆积；
  ③ 单文件超过 256KB 轮转为 `run-YYYYMMDD.log.1` 再新建，防异常刷屏写满 U 盘。
- `clean_logs.sh` 显式豁免 `helper/logs/`，避免「清理日志」把刚产生的运行日志删掉；
  想手动清空可直接删除该目录下的文件，下次点任意动作自动重建。
- 相比仅「按天数删除」，组合了按天分文件 + mtime 清理 + 数量/大小上限 + 清理功能协调，
  更便于定位与手动管理，也更抗 Kindle 时钟不准。

**校验 / Verified**
- 真机语义桩测 17/17：每项在原有副作用断言之外，新增校验运行日志增量含 `START` 与 `OK` 级别行。
- 保留策略专项 5/5：5/4 天前删除、2 天前保留；数量上限 10；256KB 轮转；清理豁免；日志原记录保留。
- 全部 `.sh` 通过 `sh -n`，9 个 `.py` 通过编译检查，无 BOM / CRLF。

**文档 / Docs**
- `config.xml` / `VERSION` 升至 v1.9.0；`README.md` 新增「运行日志与保留策略」一节并修正
  旧版「不带日志」表述；`RELEASE_NOTES.md` 中英双语同步；两个 zip 重新打包。

---

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
| v1.9 | 全部 17 个动作增加结构化运行日志；每次启动删 3 天前日志 + 数量/大小上限；「清理日志」豁免运行日志目录 |
| v1.10 | 真机日志查验；修 CA 过期的「检查更新」与只测 18 个的「修复谷歌」；「修复失效」4 项运行时禁止锁屏 |
