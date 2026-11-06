# KUAL Helper v1.9.0 — 发布说明 / Release Notes

> 单插件整合版 · 适用于 Kindle（KUAL / MRPI 环境） · 中文菜单 + 全动作屏幕反馈
> Single-extension build · for Kindle with KUAL/MRPI · Chinese menus + on-screen feedback
>
> **v1.9.0 增加运行日志与自动保留策略 / v1.9.0 adds run logs with automatic retention**

---

## 中文

### 一句话简介
把原先分散在多个 KUAL 扩展里的功能，全部收拢进**单一插件 `helper`**（直接作为 KUAL 的
Helper 菜单）。v1.9.0 给**全部 17 个动作**加上结构化运行日志：每次点击的开始与结果都写入
`helper/logs/run-YYYYMMDD.log`，按天分文件，事后可确认是否真的成功；每次动作启动自动删除
超过 3 天的旧日志，并受数量与单文件大小上限保护。v1.8.0 完成的「所有动作点击无反应」修复
与屏保 / 商店「同时选中」修复保持不变。全部菜单仍排在 MRPI 自动注入的
`Install MR Packages` 之下，每个动作保留 `Waiting...` / `Done:` / `Failed:` 屏幕反馈。

### 菜单结构
```
Helper
├─ 系统工具
│   ├─ 禁用屏保          直接 lipc 关闭屏保
│   ├─ 允许屏保          直接 lipc 恢复屏保
│   ├─ 替换商店          把商店按钮替换为 KUAL（原 KUAL-add-ons 方案）
│   ├─ 恢复商店          还原商店按钮
│   ├─ 清理SDR           只清无用 SDR 文件夹
│   ├─ 清理截图          只清截图
│   └─ 清理日志          清理所有日志与 Kindle 崩溃转储
├─ 修复失效
│   ├─ 修复封面          离线修复所有电子书封面（mobi/azw/azw3/azw4/epub/pdf）
│   ├─ 清理封面          清理所有无效封面文件（孤立 + 损坏/占位）
│   ├─ 联网修复封面      仅尝试无封面的电子书（多源回退）
│   └─ 修复谷歌          自动从 GitHub 取可用 IP、逐个测速、写 /etc/hosts
├─ 屏蔽更新
│   ├─ 屏蔽更新 / 恢复更新   BlockKindleOTA 方案开 / 关
│   ├─ 锁定更新 / 解锁更新   backdoorlock 方案开 / 关
│   └─ 删除更新              删除系统已有的更新文件
└─ 检查更新（单动作：检测到新版本才下载安装）
```

### 主要特性
- **四个中文一级菜单**：系统工具 / 修复失效 / 屏蔽更新 / 检查更新，二级动作与状态栏同样中文。
- **四个常驻独立菜单**：禁用屏保 / 允许屏保 / 替换商店 / 恢复商店，不使用状态文件与
  `if` 互斥条件，也不带 `checked` 勾选；屏保直接调用 `lipc-set-prop`，商店沿用原始
  `do.sh`，点击后只给屏幕反馈，不会残留「同时选中」的假状态。
- **全动作屏幕反馈**：`bin/msg.sh` 在点击后显示 `Waiting...`，结束显示 `Done:` 或
  `Failed:`。清理类给出删除数量与释放空间，修复谷歌给出最快 IP 与耗时，检查更新逐行
  显示版本状态；17 个动作全部覆盖。
- **封面修复**：离线为主，覆盖 6 种格式；EPUB 读 OPF 内嵌封面，PDF 支持同目录手动关联
  图片或 `.isbn` 侧车文件；可选联网补齐，数据源 Open Library → Google Books → Amazon →
  豆瓣多源回退，且「联网修复封面」只处理确实无封面的书。
- **屏蔽系统更新**：保留 BlockKindleOTA（物理屏蔽）与 backdoorlock（配置层屏蔽）两套互补
  方案，可独立开关；含「删除更新」清理已下载升级包。
- **GitHub 更新**：「检查更新」点击后查询最新 Release、比对本地 `VERSION`，仅有新版本
  才下载 `helper.zip` 解压覆盖；已是最新则只提示，插件内无需任何 token。
- **可控的运行日志**：全部动作写 `helper/logs/run-YYYYMMDD.log`，按天分文件、3 天自动清理；
  「清理日志」菜单会跳过该目录，避免误删。

### 本版变更（v1.9.0：运行日志与保留策略）
- **全部 17 个动作增加运行日志**：结果不再一闪而过。`bin/msg.sh` 在输出屏幕提示的同时，把
  `START` / `INFO` / `OK` / `FAIL` 写入新增的 `bin/log.sh` 管理的
  `helper/logs/run-YYYYMMDD.log`；按天分文件、UTF-8 追加，含时间戳、动作标识与结果文本。
  日志不可写时静默跳过，不影响动作本身。
- **每次动作启动自动清理**：`bin/log.sh` 加载时删除 3 天前及更早的日志（保留最近 3 天），
  并受「最多 10 个文件」与「单文件 256KB 轮转」两个上限保护。
- **与「清理日志」协调**：`clean_logs.sh` 显式跳过 `helper/logs/`，避免误删刚产生的运行日志。
- **降级分支同样写日志**：14 个动作脚本的 `msg.sh` 缺失兜底路径也接入 `log.sh`。
- 版本号升至 v1.9.0，`config.xml` / `VERSION` / `README.md` / `CHANGELOG.md` 同步更新。
- 上一版（v1.8.0）修复保持不变：17 个动作绝对路径 + 显式 `/bin/sh`、`KUAL_HOME` 自定位、
  移除 `checked` / `internal`、修复 `do.sh` 去掉 `local` 引发的回归。

### 安装
1. 下载 `helper.zip`（或完整包 `extensions.zip`），解压得到 `helper/` 文件夹。
2. 复制到 Kindle U 盘的 `/mnt/us/extensions/`，打开 KUAL 即出现 **Helper** 菜单。
3. 需要联网类功能（联网封面、修复谷歌、检查更新）时，请确保 Kindle 已连 WiFi；部分
   功能依赖设备上的 `curl` 与 Python 3。

### 更新
菜单「检查更新」会自动连接本仓库 `Gh9518/kual-helper` 的最新 Release。也可手动下载
新版 `helper.zip` 覆盖安装。

### 校验
- 静态：`menu.json` 合法，17 个动作全部绝对路径 + 显式 `/bin/sh`，无 `checked` /
  `internal`；全部 `.sh` 通过 `sh -n`，9 个 `.py` 通过编译检查，无 BOM / CRLF。
- **真机语义桩测 17/17**：从 `cwd='/'` 执行、脚本设为 `644` 无可执行位、不注入
  `KUAL_HOME` / `KUAL_LOG_*`，系统命令用 mock。17 个动作全部出现 `Waiting...` 与 `Done:`、
  无 `Failed:`；逐项断言副作用，并新增校验每个动作的运行日志增量均含 `START` 与 `OK` 级别行。
- **保留策略专项 5/5**：5 / 4 天前日志被删除、2 天前保留；数量上限 10 生效；单文件超 256KB
  轮转为 `.1.log`；「清理日志」删除普通 `*.log` 但豁免 `helper/logs/`；日志原有记录保持。

### 已知限制
- 「屏蔽更新」「恢复更新」执行后设备会重启，属预期行为（重启前会停留 2 秒显示结果）。
- `preventScreenSaver` 是运行时属性，Kindle 重启后会复位；需要时重新点一次「禁用屏保」。
- 屏幕提示为英文，这是 Kindle `eips` 字体的限制，菜单本身仍是中文。
- 多数 Kindle 固件对 sideload 的 PDF 不显示自定义封面，最稳妥仍是转换为 AZW3/EPUB。

### 致谢
详见 [CREDITS.md](CREDITS.md)。特别感谢**书伴（bookfere.com / BookFere）**提供的工具、
代码与教程资源，以及 KUAL、KUAL-add-ons（stepk / NiLuJe）、BlockKindleOTA、
backdoorlock、hcfyapp/google-translate-cn-ip 等项目和作者。

---

## English

### Summary
A single KUAL extension (`helper`) consolidating features previously scattered across several
extensions into the **Helper menu**. **v1.9.0 adds structured run logs to all 17 actions**: the
start and outcome of every tap are written to `helper/logs/run-YYYYMMDD.log`, one UTF-8 file per
day, so success can be verified afterwards. Logs older than 3 days are pruned automatically on
every action start, with caps on file count and per-file size. All v1.8.0 fixes (the
"every action does nothing" execution-chain repair and the screensaver/store "both selected"
state) are retained. Menus still render below the MRPI-injected `Install MR Packages`, and every
action keeps `Waiting...` / `Done:` / `Failed:` on-screen feedback.

### Menu
```
Helper
├─ 系统工具 (System Tools)   disable/enable screensaver, replace/restore store button,
│                            clear unused SDR folders / screenshots / logs
├─ 修复失效 (Repair)         offline cover fix, clean invalid covers, online cover fix,
│                            Google Translate fix
├─ 屏蔽更新 (Block Updates)  BlockKindleOTA on/off, Back Door Lock on/off, delete update files
└─ 检查更新 (Check Update)   single action: check version, install only when newer
```

### Highlights
- **Four Chinese-named top-level menus**; submenu labels and KUAL status text are Chinese too.
- **Four always-visible independent entries** for screensaver and store. No state file, no `if`
  RPN conditions, and no `checked` flag — tapping only produces on-screen feedback, never a
  lingering check mark that makes two mutually exclusive actions look "both selected".
- **On-screen feedback for all 17 actions** via `bin/msg.sh`: `Waiting...` at start,
  `Done:` / `Failed:` at the end. Cleanup actions report counts and freed space, the Google
  fix reports the chosen IP and timing, and the updater prints version status line by line.
- **Cover repair**: offline-first for `mobi/azw/azw3/azw4/epub/pdf`; EPUB OPF parsing, PDF
  sidecar image / `.isbn`; optional online fallback across Open Library → Google Books →
  Amazon → Douban, with the online action touching only books that actually lack a cover.
- **OTA blocking**: two complementary, independently switchable methods (BlockKindleOTA and
  backdoorlock) plus an update-file deleter.
- **GitHub updater**: compares the latest Release tag with local `VERSION`, downloads
  `helper.zip` only when newer; no token is embedded in the extension.
- **Managed run logs**: every action writes to `helper/logs/run-YYYYMMDD.log`, one file per day,
  auto-pruned after 3 days; the Clean Logs action skips this directory.

### Changes in this release
- **Run logs for all 17 actions**: results no longer disappear when the screen message clears.
  `bin/msg.sh` now also appends `START` / `INFO` / `OK` / `FAIL` lines to a new `bin/log.sh` that
  manages `helper/logs/run-YYYYMMDD.log` — one UTF-8 file per day with timestamp, action id and
  result text. Logging failures are silently ignored and never affect the action.
- **Automatic retention on every action start**: `bin/log.sh` deletes logs older than 3 days
  (keeps the last 3 days), with two extra caps — at most 10 files, and a 256 KB per-file rotation.
- **Coordinated with the cleanup action**: `clean_logs.sh` explicitly skips `helper/logs/`, so the
  Clean Logs action cannot delete the run logs it just produced.
- **Fallback paths log as well**: the `msg.sh`-missing fallback in all 14 action scripts loads
  `log.sh` too.
- Version bumped to v1.9.0; `config.xml`, `VERSION`, `README.md` and `CHANGELOG.md` updated.
- All v1.8.0 fixes are retained: absolute paths with explicit `/bin/sh`, `KUAL_HOME`
  self-location, removal of `checked` / `internal`, and the `do.sh` `local` regression fix.

### Install
1. Download `helper.zip` (or the full `extensions.zip`) and unzip to get `helper/`.
2. Copy it to `/mnt/us/extensions/` on the Kindle USB drive and open KUAL.
3. Network features (online covers, Google fix, updater) require WiFi; some need `curl` and
   Python 3 on the device.

### Update
`Check Update` queries the latest Release of `Gh9518/kual-helper`; a manual overwrite with a
new `helper.zip` also works.

### Verification
- Static: `menu.json` valid, all 17 actions absolute + explicit `/bin/sh`, no `checked` /
  `internal`; every `.sh` passes `sh -n`, 9 `.py` files compile, no BOM / CRLF.
- **Real-device-semantics harness: 17/17.** Executed from `cwd='/'`, scripts set to `644` (no
  executable bit), with no `KUAL_HOME` / `KUAL_LOG_*` injected and system commands mocked. All 17
  actions emitted `Waiting...` and `Done:` with no `Failed:`; each side effect was asserted, and
  each action's incremental log lines were checked to contain both `START` and `OK` levels.
- **Retention suite: 5/5.** Logs from 5 / 4 days ago deleted, 2-day-old kept; file-count cap of
  10 enforced; a file above 256 KB rotated to `.1.log`; Clean Logs removes ordinary `*.log` files
  but exempts `helper/logs/`; existing log entries preserved.

### Known limitations
- OTA block/restore reboot the device (expected); the result message stays on screen for 2
  seconds before rebooting.
- `preventScreenSaver` is a runtime property and resets after reboot — tap "禁用屏保" again.
- On-screen prompts are English due to the `eips` font; the menus themselves are Chinese.
- Most Kindle firmware does not show custom covers for sideloaded PDFs; converting to
  AZW3/EPUB remains the reliable option.

### Credits
See [CREDITS.md](CREDITS.md). Special thanks to **书伴 / BookFere (bookfere.com)** for the
tools, code and tutorials, and to KUAL, KUAL-add-ons (stepk / NiLuJe), BlockKindleOTA,
backdoorlock and hcfyapp/google-translate-cn-ip.
