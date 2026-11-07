# 更新说明 / Changelog

## v1.10.0 — 2026-11-07

**查验 / Audit（真机运行日志）**
- 依据 `run-20261107.log` 逐项核对 19 组动作：除「检查更新」「修复谷歌」两处 `FAIL` 外全部 `OK`；
  幂等分支（商店已替换、OTA 已屏蔽）、清理数量、耗时等均符合预期，也证明 v1.9.0 运行日志与
  3 天保留策略工作正常。逐项结论见 `README.md` 第十一节。

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
