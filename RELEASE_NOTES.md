# KUAL Helper v1.10.0 — 发布说明 / Release Notes

> 单插件整合版 · 适用于 Kindle（KUAL / MRPI 环境） · 中文菜单 + 全动作屏幕反馈
> Single-extension build · for Kindle with KUAL/MRPI · Chinese menus + on-screen feedback
>
> **v1.10.0 真机日志查验、故障修复与运行时防锁屏 / v1.10.0: real-device log audit, bug fixes and no-lock-during-repair**

---

## 中文

### 一句话简介
把原先分散在多个 KUAL 扩展里的功能，全部收拢进**单一插件 `helper`**（直接作为 KUAL 的
Helper 菜单）。**v1.10.0 依据一份真机运行日志逐项查验并修复两处故障**：「检查更新」在 Kindle
老固件上因 CA 证书过期失败，「修复谷歌」提示测试 117 个候选 IP 却只测了前 18 个；同时为
「修复失效」下全部 4 项增加**运行时禁止锁屏**，避免数分钟的封面 / 联网修复被休眠打断。
v1.9.0 的结构化运行日志（按天分文件、3 天自动清理）与 v1.8.0 的执行链修复保持不变。
全部菜单仍排在 MRPI 自动注入的 `Install MR Packages` 之下，每个动作保留
`Waiting...` / `Done:` / `Failed:` 屏幕反馈。

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
- **修复时禁止锁屏**：「修复失效」4 项运行时临时关闭休眠（并保住 WiFi），结束自动恢复，
  不覆盖用户手动设置的屏保状态。
- **兼容老固件**：「检查更新」遇到设备 CA 证书过期时降级重试，不再直接失败。

### 本版变更（v1.10.0：真机日志查验、故障修复与运行时防锁屏）
- **修复「检查更新」在老固件上失败**：真机日志报
  `CERTIFICATE_VERIFY_FAILED ... unable to get local issuer certificate`。`github_update.py`
  改为先正常校验 TLS，仅当错误属于证书类时降级为不校验 CA 重试（API 与网页重定向兜底
  两条路径都覆盖），并在日志留提示；超时 / 403 等非证书错误不误判。下载包仍受 zip-slip
  与 zip 结构校验约束。
- **修复「修复谷歌」的候选覆盖与判定**：旧版提示「Testing 117 candidate IPs」却由
  `MAX_TRIES=18` 只测前 18 个，前段 IP 失效即误判「No reachable IP」。本版改为**并行分批
  （每批 6 个）覆盖全部候选**，判定放宽为 `http_code=200` 且响应含译文（不再依赖固定的
  `"trans":"bonjour"` 字段），提示与实际测试数一致，失败时明确提示可能是网络阻断。
- **「修复失效」4 项增加运行时禁止锁屏**：新增 `bin/nolock.sh`，动作开始时读取当前
  `preventScreenSaver`，仅在原状态为 0 时临时设为 1，结束时恢复 0；用户已手动禁用屏保时
  不改动、不恢复。异常退出由 `trap` 保证恢复。覆盖修复封面 / 清理封面 / 联网修复封面 /
  修复谷歌，其余动作不受影响。`preventScreenSaver 1` 还能保持 WiFi 在线，对联网动作尤其关键。
- 版本号升至 v1.10.0，`config.xml` / `VERSION` / `README.md` / `CHANGELOG.md` 同步更新。
- 前两版修复保持不变：v1.9.0 的运行日志与 3 天保留策略；v1.8.0 的 17 个动作绝对路径 +
  显式 `/bin/sh`、`KUAL_HOME` 自定位、移除 `checked` / `internal`、`do.sh` 回归修复。

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
  无 `Failed:`；逐项断言副作用与运行日志增量，并新增校验「修复失效」4 项的
  `preventScreenSaver 1 → 0` 设置与恢复、其余动作不触发屏保设置。
- **专项 13/13**：保留策略 5 项（5/4 天前删除、2 天前保留、数量上限 10、256KB 轮转、
  清理豁免 + 原记录保留）；用户已禁用屏保时不改写；30 个候选中仅第 25 个可用仍能找到；
  响应体不含固定字段也能判定成功；提示与实际一致；真实证书错误可降级且超时 / 403 不误判。
- **真机日志交叉验证**：`run-20261107.log` 中除两处已修的 `FAIL` 外，19 组动作均 `OK`；
  逐项结论见 `README.md` 第十一节。

### 已知限制
- 「屏蔽更新」「恢复更新」执行后设备会重启，属预期行为（重启前会停留 2 秒显示结果）。
- `preventScreenSaver` 是运行时属性，Kindle 重启后会复位；需要时重新点一次「禁用屏保」。
- 屏幕提示为英文，这是 Kindle `eips` 字体的限制，菜单本身仍是中文。
- 「修复谷歌」依赖设备能访问 `translate.googleapis.com`；若网络本身阻断该服务，即使覆盖
  全部候选 IP 也可能全部不可达，日志会提示 `Google may be blocked on this network`。
- 多数 Kindle 固件对 sideload 的 PDF 不显示自定义封面，最稳妥仍是转换为 AZW3/EPUB。

### 致谢
详见 [CREDITS.md](CREDITS.md)。特别感谢**书伴（bookfere.com / BookFere）**提供的工具、
代码与教程资源，以及 KUAL、KUAL-add-ons（stepk / NiLuJe）、BlockKindleOTA、
backdoorlock、hcfyapp/google-translate-cn-ip 等项目和作者。

---

## English

### Summary
A single KUAL extension (`helper`) consolidating features previously scattered across several
extensions into the **Helper menu**. **v1.10.0 audits a real-device run log and fixes two
failures**: "Check Update" failed on older Kindle firmware because its CA bundle is expired, and
the Google fix advertised 117 candidate IPs while testing only the first 18. All four Repair
actions now **temporarily disable the screen lock** for the duration of the run, so multi-minute
cover / online repairs are no longer frozen by sleep. v1.9.0 run logs (one file per day, 3-day
auto-pruning) and all v1.8.0 execution-chain fixes are retained. Menus still render below the
MRPI-injected `Install MR Packages`, and every action keeps `Waiting...` / `Done:` / `Failed:`
on-screen feedback.

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
- **No screen lock during repairs**: the four Repair actions temporarily disable sleep (keeping
  WiFi alive too) and restore the previous state on exit; a user-set screensaver preference is
  never overwritten.
- **TLS fallback for older firmware**: the updater retries without CA verification only when the
  device reports a certificate error; timeouts and HTTP 403 are never misclassified.

### Changes in this release
- **Fixed "Check Update" on older firmware**: real-device logs showed
  `CERTIFICATE_VERIFY_FAILED ... unable to get local issuer certificate`. `github_update.py`
  now attempts normal TLS verification first and retries without CA verification only for
  certificate-class errors (both the API call and the `/releases/latest` web fallback), leaving
  a log line behind. Timeouts and HTTP 403 are never misclassified. Downloaded packages remain
  protected by zip-slip and archive-structure checks.
- **Fixed "Google Translate fix" candidate coverage**: the old build printed
  "Testing 117 candidate IPs" but `MAX_TRIES=18` tested only the first 18, so a few dead IPs at
  the top produced a false "No reachable IP". All candidates are now tested in parallel batches
  of 6; an IP counts as working when `http_code=200` and the body contains a translation
  (no longer tied to a fixed `"trans":"bonjour"` field). The prompt matches the actual count and
  failures explicitly mention that the network may block Google.
- **No screen lock during Repair actions**: new `bin/nolock.sh` reads the current
  `preventScreenSaver`, temporarily sets it to 1 only when it was 0, and restores it on exit;
  if the user already disabled the screensaver, nothing is changed or restored. `trap` covers
  abnormal exits. Applies to all four Repair actions; other actions are unaffected.
- Version bumped to v1.10.0; `config.xml`, `VERSION`, `README.md`, `CHANGELOG.md` updated.
- All v1.9.0 and v1.8.0 fixes are retained (run logs with 3-day retention; absolute paths with
  explicit `/bin/sh`, `KUAL_HOME` self-location, removal of `checked` / `internal`, and the
  `do.sh` `local` regression fix).

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
  actions emitted `Waiting...` and `Done:` with no `Failed:`; side effects and incremental run-log
  lines asserted, plus new checks that the four Repair actions set and restore
  `preventScreenSaver` while no other action touches it.
- **Special suites: 13/13.** Retention (5/4-day deletion, 2-day keep, 10-file cap, 256 KB
  rotation, Clean Logs exemption), no overwrite when the user already disabled the screensaver,
  30 candidates with only the 25th reachable still succeed, relaxed response matching, prompt
  accuracy, and real `CERTIFICATE_VERIFY_FAILED` triggering a TLS fallback without misclassifying
  timeouts / 403.
- **Cross-checked against a real-device log**: in `run-20261107.log`, all 19 action runs were
  `OK` except the two failures fixed in this release; per-action conclusions are in
  `README.md` section 11.

### Known limitations
- OTA block/restore reboot the device (expected); the result message stays on screen for 2
  seconds before rebooting.
- `preventScreenSaver` is a runtime property and resets after reboot — tap "禁用屏保" again.
- On-screen prompts are English due to the `eips` font; the menus themselves are Chinese.
- The Google fix needs reachability to `translate.googleapis.com`; if the network blocks it, no
  candidate IP will work and the log says `Google may be blocked on this network`.
- Most Kindle firmware does not show custom covers for sideloaded PDFs; converting to
  AZW3/EPUB remains the reliable option.

### Credits
See [CREDITS.md](CREDITS.md). Special thanks to **书伴 / BookFere (bookfere.com)** for the
tools, code and tutorials, and to KUAL, KUAL-add-ons (stepk / NiLuJe), BlockKindleOTA,
backdoorlock and hcfyapp/google-translate-cn-ip.
