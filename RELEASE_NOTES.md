# KUAL Helper v1.6.0 — 发布说明 / Release Notes

> 单插件整合版 · 适用于 Kindle（KUAL / MRPI 环境） · 首次正式发布
> Single-extension build · for Kindle with KUAL/MRPI · first public release

---

## 中文

### 一句话简介
把原先分散在多个 KUAL 扩展里的功能，全部收拢进**单一插件 `helper`**（直接作为 KUAL 的
Helper 菜单），按 4 个一级菜单组织，全部菜单排在 MRPI 自动注入的 `Install MR Packages`
之下；不带任何日志，并支持从 GitHub 一键检查更新。

### 菜单结构
```
Helper
├─ System Tools    系统工具
│   ├─ 禁用屏保 / 允许屏保   互斥开关，只占 1 个菜单位
│   ├─ 屏蔽商店 / 恢复商店   互斥开关
│   ├─ 清理SDR              只清无用 SDR 文件夹
│   ├─ 清理截图              只清截图
│   └─ 清理日志              清理所有日志与 Kindle 崩溃转储
├─ Repair          修复失效
│   ├─ 修复封面              离线修复所有电子书封面（mobi/azw/azw3/azw4/epub/pdf）
│   ├─ 清理封面              清理所有无效封面文件（孤立 + 损坏/占位）
│   ├─ 联网修复封面          仅尝试无封面的电子书（多源回退）
│   └─ 修复谷歌              自动从 GitHub 取可用 IP、逐个测速、写 /etc/hosts
├─ Block Updates   屏蔽更新
│   ├─ 屏蔽更新 / 恢复更新   BlockKindleOTA 方案开 / 关
│   ├─ 锁定更新 / 解锁更新   backdoorlock 方案开 / 关
│   └─ 删除更新              删除系统已有的更新文件
└─ Check Update    检查更新（单动作：检测到新版本才下载安装）
```

### 主要特性
- **单一插件、四个一级菜单（英文名）**：System Tools / Repair / Block Updates / Check Update。
- **两处互斥开关**：屏保与商店按钮都由 KUAL `if` 条件在两个动作间切换显示，视觉上各只占
  一个菜单位，减少菜单数量。
- **封面修复**：离线为主，覆盖 6 种格式；EPUB 读 OPF 内嵌封面，PDF 支持同目录手动关联
  图片或 `.isbn` 侧车文件；可选联网补齐，数据源 Open Library → Google Books → Amazon →
  豆瓣多源回退，且「联网修复封面」只处理确实无封面的书。
- **修复谷歌**：从 `hcfyapp/google-translate-cn-ip` 的 6 个 GitHub/CDN 地址自动取 IP 列表
  （选最快源），逐个真实请求翻译接口筛选可用 IP，按耗时排序把最快的写入 `/etc/hosts`，
  其余记为备用注释；全源不可达时回退内置候选。
- **屏蔽系统更新**：保留 BlockKindleOTA（物理屏蔽）与 backdoorlock（配置层屏蔽）两套互补
  方案，可独立开关；含「删除更新」清理已下载升级包。
- **GitHub 更新**：`Check Update` 点击后查询最新 Release、比对本地 `VERSION`，仅有新版本
  才下载 `helper.zip` 解压覆盖；已是最新则只提示。
- **全程不带日志**：所有动作只在屏幕给出结果，不生成任何日志文件。

### 安装
1. 下载 `helper.zip`（或完整包 `_extensions.zip`），解压得到 `helper/` 文件夹。
2. 复制到 Kindle U 盘的 `/mnt/us/extensions/`，打开 KUAL 即出现 **Helper** 菜单。
3. 需要联网类功能（联网封面、修复谷歌、检查更新）时，请确保 Kindle 已连 WiFi；部分
   功能依赖设备上的 `curl` 与 Python 3。

### 更新
菜单 `Check Update` 会自动连接本仓库 `Gh9518/kual-helper` 的最新 Release。也可手动下载
新版 `helper.zip` 覆盖安装。

### 本版代码审查与修复
- 修复 `FixCover.handle()` 传入空路径时抛 `TypeError`、可变默认参数、Linux 下 Kindle 根目录
  自动探测失效。
- 修复 DB 模式下封面修复成功却误报「无需修复」；`Path.unlink(True)` 改为兼容
  Python 3.5+ 的写法。
- 修复「修复谷歌」反复运行导致 `/etc/hosts` 统计行无限累积、curl 缺失判断用错逻辑运算符。
- 为「屏蔽更新 / 恢复更新」加入幂等保护：重复点击不再覆盖 OTA 二进制备份，避免无法恢复。
- 重写 SDR 清理：修正电子书后缀识别、支持递归子目录、移除无效逻辑。
- 为更新器增加 zip-slip 路径穿越防护；清理 backdoorlock 残留的日志写入。
- 更新器在匿名 GitHub API 被限流（HTTP 403）时改用网页重定向兜底，并对下载加入重试，
  共享网络 / 弱网下「检查更新」仍可用（无需在插件内放置任何 token）。

### 已知限制
- 「屏蔽更新」「恢复更新」执行后设备会重启，属预期行为。
- 屏保状态基于运行时属性，重启后可能复位；菜单标记与实际不一致时点一次对应开关即可同步。
- 多数 Kindle 固件对 sideload 的 PDF 不显示自定义封面，最稳妥仍是转换为 AZW3/EPUB。

### 致谢
详见 [CREDITS.md](CREDITS.md)。特别感谢**书伴（bookfere.com / BookFere）**提供的工具、
代码与教程资源，以及 KUAL、KUAL-add-ons（stepk / NiLuJe）、BlockKindleOTA、
backdoorlock、hcfyapp/google-translate-cn-ip 等项目和作者。

---

## English

### Summary
A single KUAL extension (`helper`) that consolidates features previously scattered across
several extensions into the **Helper menu**, organised under four top-level menus, always
rendered below the MRPI-injected `Install MR Packages`. No log files are produced, and a
one-tap GitHub updater is included.

### Menu
```
Helper
├─ System Tools    screensaver toggle, store toggle, clear SDR / screenshots / logs
├─ Repair          offline cover fix, clean invalid covers, online cover fix, Google Translate fix
├─ Block Updates   BlockKindleOTA on/off, Back Door Lock on/off, delete update files
└─ Check Update    single action: check version, install only when a newer release exists
```

### Highlights
- **One extension, four English-named top-level menus.**
- **Two mutually-exclusive toggles** (screensaver, store button) via KUAL `if` RPN conditions —
  each occupies a single visible slot.
- **Cover repair**: offline-first for `mobi/azw/azw3/azw4/epub/pdf`; EPUB OPF parsing, PDF
  sidecar image / `.isbn`; optional online fallback across Open Library → Google Books →
  Amazon → Douban, and the online action only touches books that actually lack a cover.
- **Google Translate fix**: fetch IP list from 6 GitHub/CDN mirrors of
  `hcfyapp/google-translate-cn-ip` (fastest source wins), probe each IP against the real
  translate endpoint, write the fastest reachable IP into `/etc/hosts` with backups as
  comments; static candidates used if all sources fail.
- **OTA blocking**: two complementary, independently switchable methods (BlockKindleOTA and
  backdoorlock) plus an update-file deleter.
- **GitHub updater**: compares the latest Release tag with local `VERSION`, downloads
  `helper.zip` only when newer, then extracts over the extension directory.
- **No logs anywhere**: every action reports on-screen only.

### Install
1. Download `helper.zip` (or the full `_extensions.zip`) and unzip to get `helper/`.
2. Copy it to `/mnt/us/extensions/` on the Kindle USB drive and open KUAL.
3. Network features (online covers, Google fix, updater) require WiFi; some need `curl` and
   Python 3 on the device.

### Update
`Check Update` queries the latest Release of `Gh9518/kual-helper`; a manual overwrite with a
new `helper.zip` also works.

### Code review fixes in this release
- Fixed `FixCover.handle()` crashing on an empty path, its mutable default argument, and
  broken Kindle-root auto-detection on Linux.
- Fixed the DB path reporting "nothing to fix" after a successful repair; replaced
  `Path.unlink(True)` with a Python 3.5-compatible deletion.
- Fixed unbounded `/etc/hosts` growth on repeated Google-fix runs and a wrong curl check.
- Added idempotency guards to OTA block/restore so repeated taps can no longer overwrite the
  real binary backup (which previously made restore impossible).
- Rewrote the SDR cleaner (correct ebook suffix matching, recursive subdirectories, dead-code
  removal).
- Added zip-slip protection to the updater; removed leftover log writes in backdoorlock.
- The updater now falls back to the `/releases/latest` web redirect when the anonymous GitHub
  API is rate-limited (HTTP 403), and retries downloads once — so `Check Update` still works on
  shared/slow networks without embedding any token in the extension.

### Known limitations
- OTA block/restore reboot the device (expected).
- The screensaver toggle relies on a runtime property and may reset after reboot; tap once to
  re-sync if the menu state and actual state diverge.
- Most Kindle firmware does not show custom covers for sideloaded PDFs; converting to
  AZW3/EPUB remains the reliable option.

### Credits
See [CREDITS.md](CREDITS.md). Special thanks to **书伴 / BookFere (bookfere.com)** for the
tools, code and tutorials, and to KUAL, KUAL-add-ons (stepk / NiLuJe), BlockKindleOTA,
backdoorlock and hcfyapp/google-translate-cn-ip.
