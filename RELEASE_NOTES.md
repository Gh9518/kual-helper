# KUAL Helper v1.7.0 — 发布说明 / Release Notes

> 单插件整合版 · 适用于 Kindle（KUAL / MRPI 环境） · 中文菜单 + 全动作屏幕反馈
> Single-extension build · for Kindle with KUAL/MRPI · Chinese menus + on-screen feedback

---

## 中文

### 一句话简介
把原先分散在多个 KUAL 扩展里的功能，全部收拢进**单一插件 `helper`**（直接作为 KUAL 的
Helper 菜单）。本版把菜单改回中文、把屏保与商店恢复为四个独立菜单的原始方案，并为**每一个
动作**加入 `Waiting...` / `Done:` / `Failed:` 屏幕反馈；全部菜单仍排在 MRPI 自动注入的
`Install MR Packages` 之下，且不生成任何日志。

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
- **屏保与商店恢复原方案**：四个独立常驻菜单，去掉状态文件与 `if` 互斥条件；屏保直接调用
  `lipc-set-prop`，商店沿用原始 `do.sh`，不再因固件路径差异或重启后状态不一致而隐藏菜单。
- **全动作屏幕反馈**：新增 `bin/msg.sh`，点击即显示 `Waiting...`，结束显示 `Done:` 或
  `Failed:`。清理类给出删除数量与释放空间，修复谷歌给出最快 IP 与耗时，检查更新逐行显示
  版本状态；清理、修复、屏蔽更新、检查更新、屏保、商店共 17 个动作全部覆盖。
- **封面修复**：离线为主，覆盖 6 种格式；EPUB 读 OPF 内嵌封面，PDF 支持同目录手动关联
  图片或 `.isbn` 侧车文件；可选联网补齐，数据源 Open Library → Google Books → Amazon →
  豆瓣多源回退，且「联网修复封面」只处理确实无封面的书。
- **屏蔽系统更新**：保留 BlockKindleOTA（物理屏蔽）与 backdoorlock（配置层屏蔽）两套互补
  方案，可独立开关；含「删除更新」清理已下载升级包。
- **GitHub 更新**：「检查更新」点击后查询最新 Release、比对本地 `VERSION`，仅有新版本
  才下载 `helper.zip` 解压覆盖；已是最新则只提示，插件内无需任何 token。
- **全程不带日志**：所有动作只在屏幕给出结果，不生成任何日志文件。

### 本版变更
- 一级菜单与 KUAL 状态文本由英文改回中文。
- 删除 `.screensaver_disabled` 标记文件与全部 `if` 条件，屏保 / 商店改为四个独立菜单。
- 商店脚本补上失败分支的 `mntroot ro`，并在不支持的固件上明确提示，避免静默无反应。
- 新增统一反馈模块 `bin/msg.sh`；`config.sh` 的 `print_log` 一并接入，去掉 `&>` 这类
  bash 专用写法，兼容 Kindle 的 `sh`。
- 屏幕提示统一用简短英文（Kindle `eips` 使用固化 ASCII 字体，中文会显示为方块）；
  菜单与 KUAL 状态栏仍为中文。
- 版本号升至 v1.7.0，`README.md` / `CHANGELOG.md` 同步更新。

### 安装
1. 下载 `helper.zip`（或完整包 `extensions.zip`），解压得到 `helper/` 文件夹。
2. 复制到 Kindle U 盘的 `/mnt/us/extensions/`，打开 KUAL 即出现 **Helper** 菜单。
3. 需要联网类功能（联网封面、修复谷歌、检查更新）时，请确保 Kindle 已连 WiFi；部分
   功能依赖设备上的 `curl` 与 Python 3。

### 更新
菜单「检查更新」会自动连接本仓库 `Gh9518/kual-helper` 的最新 Release。也可手动下载
新版 `helper.zip` 覆盖安装。

### 校验
- 隔离桩测 17 个菜单动作：全部出现 `Waiting...` 与 `Done:` / `Failed:` 提示。
- 屏保 `lipc-set-prop ... preventScreenSaver 1/0` 调用正确；商店替换 / 恢复真实改写
  `search_bar.js` 并能完整还原、备份文件正确清理。
- 全部 `.sh` 通过 `sh -n`、全部 `.py` 通过编译检查，`menu.json` 结构合法。

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
extensions into the **Helper menu**. This release restores Chinese menus, returns the
screensaver and store-button controls to four independent menu entries (the original scheme),
and adds `Waiting...` / `Done:` / `Failed:` on-screen feedback to **every** action. All menus
still render below the MRPI-injected `Install MR Packages`, and no log files are produced.

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
- **Original screensaver / store scheme restored**: four always-visible independent entries.
  The `.screensaver_disabled` marker and all `if` RPN conditions were removed, so menus no
  longer disappear because of firmware path differences or a stale state after reboot.
  Screensaver scripts call `lipc-set-prop` directly; the store button keeps the original
  `KUAL-add-ons` `do.sh` logic.
- **On-screen feedback for all 17 actions** via a new `bin/msg.sh`: `Waiting...` at start,
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
- Top-level menus and status text switched back from English to Chinese.
- Removed the `.screensaver_disabled` marker and every `if` condition; screensaver and store
  controls are now four independent entries.
- Store scripts now always return the root filesystem to read-only on failure and report
  unsupported firmware explicitly instead of failing silently.
- Added the shared `bin/msg.sh` feedback module; `config.sh` `print_log` now uses it and no
  longer relies on the bash-only `&>` redirection.
- Screen prompts are short English strings: Kindle's `eips` uses a fixed ASCII font and would
  render Chinese as boxes. Menus and KUAL status text remain Chinese.
- Version bumped to v1.7.0; `README.md` and `CHANGELOG.md` updated accordingly.

### Install
1. Download `helper.zip` (or the full `extensions.zip`) and unzip to get `helper/`.
2. Copy it to `/mnt/us/extensions/` on the Kindle USB drive and open KUAL.
3. Network features (online covers, Google fix, updater) require WiFi; some need `curl` and
   Python 3 on the device.

### Update
`Check Update` queries the latest Release of `Gh9518/kual-helper`; a manual overwrite with a
new `helper.zip` also works.

### Verification
- All 17 menu actions were exercised in an isolated harness: every one emitted `Waiting...`
  plus `Done:` / `Failed:`.
- Screensaver calls `preventScreenSaver 1/0` correctly; store replace/restore really rewrites
  `search_bar.js` and restores it cleanly, removing the backup file.
- Every `.sh` passes `sh -n`, every `.py` compiles, and `menu.json` is valid.

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
