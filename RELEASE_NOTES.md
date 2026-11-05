# KUAL Helper v1.8.0 — 发布说明 / Release Notes

> 单插件整合版 · 适用于 Kindle（KUAL / MRPI 环境） · 中文菜单 + 全动作屏幕反馈
> Single-extension build · for Kindle with KUAL/MRPI · Chinese menus + on-screen feedback
>
> **v1.8.0 是全功能修复版 / v1.8.0 is an all-actions bug-fix release**

---

## 中文

### 一句话简介
把原先分散在多个 KUAL 扩展里的功能，全部收拢进**单一插件 `helper`**（直接作为 KUAL 的
Helper 菜单）。v1.8.0 回到最初上传的原始插件逐项核对，修复了「**所有菜单点击后都无反应**」
这一共性故障：17 个动作全部改为绝对路径 + 显式 `/bin/sh` 调用，脚本自行定位插件根目录、
不再依赖工作目录与可执行位；同时删除点击后残留的勾选标记，屏保 / 商店不再出现
「同时选中」的假状态。全部菜单仍排在 MRPI 自动注入的 `Install MR Packages` 之下，
每个动作保留 `Waiting...` / `Done:` / `Failed:` 屏幕反馈，且不生成任何日志。

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
- **全程不带日志**：所有动作只在屏幕给出结果，不生成任何日志文件。

### 本版变更（v1.8.0 修复）
- **根因**：v1.7.0 菜单用相对 `./bin/...` 调用脚本，脚本内又以 `. ./bin/config.sh` /
  `. ./bin/msg.sh` 加载依赖，隐含假设 KUAL 执行时的工作目录就是插件目录，并依赖可执行位
  与 shebang；任一条件不满足，动作即静默失败。对照原始上传包，能工作的屏保脚本是零依赖
  的极简 `lipc` 调用，BlockKindleOTA / backdoorlock 菜单也只有
  `name / priority / action / exitmenu` 四个字段。
- `menu.json`：17 个 `action` 全部改为 `/bin/sh /mnt/us/extensions/helper/bin/...`；
  删除全部 `checked` 与 `internal`，保留 `status:false`；四个屏保 / 商店菜单常驻独立。
  删除 `checked` 后不再出现「禁用屏保 / 允许屏保」「替换商店 / 恢复商店」同时勾选。
- 全部 14 个 `.sh` 加入 `KUAL_HOME` 自定位（由 `$0` 真实路径向上查找 `config.xml`），
  `config.sh` / `msg.sh` / Python 入口一律改为 `$KUAL_HOME/bin/...` 绝对路径。
- 依赖加载加 fallback：`config.sh` 或 `msg.sh` 不可读时定义最小反馈函数，避免 POSIX `sh`
  因 `.` 失败直接终止；`msg.sh` 加 `eips` 兜底与末尾 `:`，保证被加载时返回 0。
- 去掉非 POSIX 写法（`source` / `&>` / `==` / `local`），`updatewait` 的日志改写到
  `/dev/null`，`fix-google-translate.sh` 补 `grep` / `sed` / `curl` 命令兜底。
- **修复 `do.sh` 回归**：去掉原版 `local verb=... btnpath=... bak` 的 `local` 后，裸
  `bak` 会被当作命令执行，前置赋值只在该命令环境生效，导致 `btnpath` 恒为空、商店两项
  必然报 `Store button file not found (unsupported firmware)`。已按原版语义改为逐行赋值。
- 版本号升至 v1.8.0，`config.xml` / `VERSION` / `README.md` / `CHANGELOG.md` 同步更新。

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
- **真机语义桩测 17/17 通过**：从 `cwd='/'` 执行、脚本设为 `644` 无可执行位、不注入
  `KUAL_HOME` / `KINDLE_PATH` / `KUAL_EIPS`，系统命令用 mock。17 个动作全部出现
  `Waiting...` 与 `Done:`、无 `Failed:`；并逐项断言副作用：
  `preventScreenSaver 1/0`、商店 `search_bar.js` 改写与还原（含 `.KUAL_bak` 生成/清除）、
  崩溃日志删除、`/etc/hosts` 写入最快 IP、OTA 二进制改名与还原、backdoorlock 配置劫持与
  还原、更新包删除、更新检查执行。

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
extensions into the **Helper menu**. **v1.8.0 is an all-actions bug-fix release**: we went back
to the originally uploaded extensions and fixed the common cause behind "every menu item does
nothing when tapped". All 17 actions now use absolute paths with an explicit `/bin/sh`, and each
script locates the extension root itself instead of relying on the working directory or the
executable bit. The stale check marks were removed, so the screensaver and store entries can no
longer appear "both selected". Menus still render below the MRPI-injected
`Install MR Packages`, every action keeps `Waiting...` / `Done:` / `Failed:` feedback, and no
log files are produced.

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
- **No logs anywhere**: every action reports on-screen only.

### Changes in this release
- **Root cause**: v1.7.0 invoked scripts via relative `./bin/...` paths, and the scripts sourced
  `. ./bin/config.sh` / `. ./bin/msg.sh`, silently assuming KUAL's working directory was the
  extension root (and relying on the executable bit and shebang). If any assumption failed, the
  action did nothing. In the original upload, the working screensaver scripts were dependency-free
  `lipc` calls and the BlockKindleOTA / backdoorlock menus only had
  `name / priority / action / exitmenu`.
- `menu.json`: all 17 actions are now `/bin/sh /mnt/us/extensions/helper/bin/...`; every
  `checked` and `internal` was removed, `status:false` kept. Removing `checked` fixes the
  apparent "both selected" state of the screensaver and store pairs.
- All 14 shell scripts now self-locate `KUAL_HOME` (walk up from `$0` to find `config.xml`);
  `config.sh`, `msg.sh` and the Python entry points use `$KUAL_HOME/bin/...` absolute paths.
- Loading fallbacks: minimal feedback functions are defined when `config.sh` / `msg.sh` are
  unreadable, so POSIX `sh` no longer aborts on a failed `.`; `msg.sh` gained an `eips`
  fallback and a trailing `:` to guarantee a zero return when sourced.
- Removed non-POSIX syntax (`source` / `&>` / `==` / `local`); `updatewait` now logs to
  `/dev/null`; the Google fix gained `grep` / `sed` / `curl` command fallbacks.
- **Fixed a `do.sh` regression**: after dropping `local` from the original
  `local verb=... btnpath=... bak`, the bare `bak` became a command and the preceding
  assignments applied only to that command's environment, leaving `btnpath` empty so both store
  actions always reported `Store button file not found (unsupported firmware)`. The line was
  split into explicit per-variable assignments, restoring the original semantics.
- Version bumped to v1.8.0; `config.xml`, `VERSION`, `README.md` and `CHANGELOG.md` updated.

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
- **Real-device-semantics harness: 17/17 passed.** Executed from `cwd='/'`, scripts set to
  `644` (no executable bit), with no `KUAL_HOME` / `KINDLE_PATH` / `KUAL_EIPS` injected and
  system commands mocked. All 17 actions emitted `Waiting...` and `Done:` with no `Failed:`,
  and each side effect was asserted: `preventScreenSaver 1/0`, store `search_bar.js` rewrite
  and restore (including `.KUAL_bak` creation/removal), crash-log deletion, fastest IP written
  to `/etc/hosts`, OTA binary rename/restore, backdoorlock config hijack/restore, update package
  deletion, and update check execution.

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
