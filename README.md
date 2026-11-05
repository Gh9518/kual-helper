# KUAL Helper（单插件整合版 v1.8.0）

把原先分散在多个插件里的功能**全部整合为单一插件 `helper`**。安装文件夹名即 `helper`，
直接作为 KUAL 的 **Helper** 菜单出现。

- 正式仓库：**[github.com/Gh9518/kual-helper](https://github.com/Gh9518/kual-helper)**
- 中英双语发布说明：[RELEASE_NOTES.md](RELEASE_NOTES.md) ｜ 更新说明：[CHANGELOG.md](CHANGELOG.md) ｜ 致谢：[CREDITS.md](CREDITS.md)
- 菜单里的「检查更新」会自动连接上述仓库的最新 Release 检查并安装更新。

> v1.8.0 是**全功能修复版**：回到最初上传的原始插件逐项核对，修掉导致「所有菜单点击都无反应」
> 的共性执行链问题（相对路径、工作目录、`source` 失败、可执行位假设）。17 个动作全部改为
> **绝对路径 + 显式 `/bin/sh` 调用**，脚本自行定位插件根目录；同时删除点击后残留的勾选标记，
> 屏保 / 商店不再出现「同时选中」的假状态。`Waiting...` / `Done:` / `Failed:` 反馈保持不变。

## 一、菜单结构（全部中文、无日志）

```
Helper                     (priority -998)
├─ 系统工具                (priority 1000)
│   ├─ 禁用屏保            ssprevent.sh                 lipc 直接关闭屏保
│   ├─ 允许屏保            ssallow.sh                   lipc 直接恢复屏保
│   ├─ 替换商店            do.sh toggle_store_button replace
│   ├─ 恢复商店            do.sh toggle_store_button restore
│   ├─ 清理SDR             sdr_cleaner.sh --sdr        只清无用 SDR 文件夹
│   ├─ 清理截图            sdr_cleaner.sh --shot --no-sdr 只清截图
│   └─ 清理日志            clean_logs.sh               清理所有日志与崩溃转储
├─ 修复失效                (priority 1010)
│   ├─ 修复封面            fix_cover.sh                离线修复所有电子书封面
│   ├─ 清理封面            fix_cover.sh --clean        清理所有无效封面文件
│   ├─ 联网修复封面        fix_cover.sh --net --missing-only  仅尝试无封面的电子书
│   └─ 修复谷歌            fix_google_translate.sh     GitHub 取 IP → 逐个测试 → 写 hosts
├─ 屏蔽更新                (priority 1020)
│   ├─ 屏蔽更新            block-ota/rename.sh         BlockKindleOTA 开启
│   ├─ 恢复更新            block-ota/restore.sh        BlockKindleOTA 关闭并恢复
│   ├─ 锁定更新            backdoorlock/lock.sh        backdoorlock 开启
│   ├─ 解锁更新            backdoorlock/unlock.sh      backdoorlock 关闭并恢复
│   └─ 删除更新            backdoorlock/delete.sh      删除系统已有的更新文件
└─ 检查更新                (priority 1030，单动作)
    └─ github_update.sh    点击 → 检测版本 → 有新版本才下载安装
```

> 所有菜单项均**不带日志**：不生成任何日志文件，结果只在屏幕提示。
> `menu.json` 里 17 个 `action` 全部是**绝对路径**且以显式 `/bin/sh` 开头，例如
> `/bin/sh /mnt/us/extensions/helper/bin/ssprevent.sh`。这样既不依赖 KUAL 调用时的工作
> 目录，也不要求脚本带可执行位——这是 v1.8.0 修复「点击无反应」的关键。

### 一级菜单名（中文）

| 中文 | 曾用的英文 |
|---|---|
| 系统工具 | System Tools |
| 修复失效 | Repair |
| 屏蔽更新 | Block Updates |
| 检查更新 | Check Update |

二级动作名与 KUAL 状态栏文本同样为中文。

### 屏幕反馈

`bin/msg.sh` 统一封装 Kindle 的 `eips`：动作一被点击就在屏幕第 3 行显示
`Waiting... <任务>`，结束时在第 4 行显示 `Done: <结果>` 或 `Failed: <原因>`。
17 个动作全部接入，反馈内容按功能给出实际结果：

| 类别 | 运行中提示 | 结束提示示例 |
|---|---|---|
| 清理三项 | `Waiting... Cleaning unused SDR folders` 等 | `Done: Removed 1 unused SDR folder(s)`、`Done: 2 log/crash file(s) removed, 0.0 MB freed` |
| 修复四项 | `Waiting... Fixing damaged ebook covers` 等 | `Done: Ebook covers fixed`、`Done: Fastest IP 142.250.x.x written (0.12s, 2/2 ok)` |
| 屏蔽更新五项 | `Waiting... Blocking OTA updates` 等 | `Done: OTA binaries replaced, rebooting...`、`Done: 1 update file(s) deleted` |
| 检查更新 | `Waiting... Checking GitHub for updates` | 逐行显示版本状态，最后 `Done: Update check finished` |
| 屏保 / 商店 | `Waiting... Disabling screen saver` 等 | `Done: Screen saver disabled`、`Done: Store button restored - please restart your Kindle` |

> 屏幕提示用简短**英文**：Kindle 的 `eips` 使用固化 ASCII 字体，中文会显示为方块；
> 菜单与 KUAL 状态栏由 KUAL 自身渲染，中文正常显示。

## 二、Install MR Packages：不再内置，改用系统自动项

- 内置的 `Install MR Packages`（`bin/install_mr.sh`）已**删除**——真机 KUAL/MRPI
  会**自动注入**这个按钮，无需插件重复提供，避免出现两个同名项。
- KUAL 菜单按 `priority` **升序**排列（数值越小越靠上）。自动注入的 `Install MR Packages`
  通常是小/负 priority；本插件 4 个菜单保持 `1000 / 1010 / 1020 / 1030`（大正数），
  因此**所有功能菜单仍严格排在其下方**。

## 三、屏保与商店：四个常驻独立菜单

屏保与商店保持四个**常驻独立菜单**，随时可点、互不隐藏：

- 不使用状态文件与 `if` 互斥条件——新固件上 `search_bar.js` 路径可能不同，`if` 条件
  会让商店菜单整个消失；重启后状态文件与 `preventScreenSaver` 运行时属性也可能不一致。
- `ssprevent.sh` / `ssallow.sh` 沿用原始 helper 的直接调用：
  `lipc-set-prop -i com.lab126.powerd preventScreenSaver 1` / `0`，并检查返回码给出
  成功或失败反馈。`preventScreenSaver` 是运行时属性，重启后会复位，需要时再点一次即可。
- `替换商店` / `恢复商店` 沿用 KUAL-add-ons 的原始 `do.sh toggle_store_button` 逻辑
  （备份 `search_bar.js.KUAL_bak` → `sed` 替换为 KUAL → 重启后生效）；失败分支补上
  `mntroot ro`，并在不支持的固件、已替换 / 无需恢复等情况下都给出明确提示。

> **v1.8.0 关键修复**：菜单里已删除 `checked` 字段。此前四个动作项都带 `checked:true`，
> KUAL 会在点击后留下勾选标记，于是「禁用屏保 / 允许屏保」「替换商店 / 恢复商店」看起来
> 能同时选中。现在它们是普通动作，点击后只给出屏幕反馈，不再残留任何勾选状态。
>
> 同一轮还修掉了 `do.sh` 的一处回归：为兼容 POSIX `sh` 去掉原版
> `local verb=... btnpath=... bak` 的 `local` 后，裸 `bak` 会被当成命令执行，前置赋值
> 只作用于该命令的环境，导致 `btnpath` 恒为空、商店两项必然报
> `Store button file not found (unsupported firmware)`。现已按原版语义改为逐行赋值。

### 清理三项归到末尾
`清理SDR`、`清理截图`、`清理日志` 三个"清理"类动作集中在 **系统工具的最后三位**
（priority 5/6/7），前面留给屏保、商店四个动作，分类更清晰。

## 四、系统工具：清理日志

`bin/clean_logs.sh`：清理 **USB 可见区 `/mnt/us`**（含 `documents/`、`extensions/`、`system/`
等子目录，深度 3）内的两类文件：

1. **所有日志文件**：`*.log`、`*.log.*`（轮转日志）、`*.trace`、`*.logfile`；
2. **Kindle 崩溃日志 / 转储**（5.16.x+ 固件会在主屏幕不断生成的 4 类文件）：

| # | 命名 | 典型文件名 |
|---|---|---|
| ① | `Indexer_Dump*` | `Indexer_Dump_1727406757193.txt` |
| ② | `cvm_*`（含设备代号 juno） | `cvm_12345_037-juno_16021_...` |
| ③ | `KPPMainApp*` | `KPPMainApp`、`KPPMainAppV2` |
| ④ | `Mesquite*` | `Mesquite_...` |

另外一并清理同类变体：`*_crash_*.txt / .tgz / .sdr`、`*.core`（约 30MB 的大转储）、
`Indexer*.dump*`，避免遗漏。

**安全性**
- 只按**文件名**匹配、大小写不敏感（`Indexer_Dump` 与 `indexer_dump` 都能清）；
- 不按内容或宽泛扩展名删除，电子书、普通文档、`DISABLE_CORE_DUMP` 等抑制文件均会保留；
- 不动系统分区（`/var/log` 等），自身也不写日志，只在屏幕提示清理数量与释放空间。

> 想从源头阻止崩溃日志再次生成，可在 U 盘根目录放一个**无扩展名**的空文件
> `DISABLE_CORE_DUMP`（可选再加 `DISABLE_CORE_DUMP_ALERT`）；本功能负责清理已产生的文件。

## 五、修复失效：实现说明

### 修复封面（离线）
`fix_cover.sh` → `fix_cover.py`：从电子书**文件内嵌**的封面图提取并写回 Kindle 缩略图库，
覆盖 `.mobi / .azw / .azw3 / .azw4 / .epub / .pdf`（PDF 支持同目录 `书名.cover.jpg` 手动关联）。
完全离线，不联网。

### 清理封面（清理所有无效封面文件）
`fix_cover.sh --clean`：删除两类无效封面——
1. **孤立封面**：缩略图存在但已无对应电子书；
2. **损坏 / 占位封面**：小于 2KB 的空白缩略图。

### 联网修复封面（仅无封面的电子书）
`fix_cover.sh --net --missing-only`：**已有正常封面的书直接跳过**，只对「缩略图缺失或已损坏」
的书尝试联网获取。多源回退顺序为 **Open Library → Google Books → Amazon → 豆瓣**，
任一成功即止；只接受合法 JPEG/PNG，丢弃 1×1 占位图，单源超时 6s 快速失败。
联网动作耗时较长，运行时会持续显示 `Waiting...` 提示。

### 修复谷歌（从 GitHub 自动取 IP）
`fix_google_translate.sh` 三步：
1. **自动查找**：逐个测速下列 GitHub / GitHub-CDN 备选源，选**最快且返回有效 IP 列表**的一个
   （源由社区项目 `hcfyapp/google-translate-cn-ip` 维护，专供 `translate.googleapis.com`）：

   | # | 源 |
   |---|---|
   | 1 | `raw.githubusercontent.com/hcfyapp/google-translate-cn-ip/main/ips.txt` |
   | 2 | `raw.githubusercontent.com/hcfyapp/google-translate-cn-ip/master/packages/google-translate-ip/ips.txt` |
   | 3 | `unpkg.com/@hcfy/google-translate-ip/ips.txt` |
   | 4 | `fastly.jsdelivr.net/npm/@hcfy/google-translate-ip/ips.txt` |
   | 5 | `cdn.jsdelivr.net/npm/@hcfy/google-translate-ip/ips.txt` |
   | 6 | `cdn.jsdelivr.net/gh/hcfyapp/google-translate-cn-ip@master/packages/google-translate-ip/ips.txt` |

   6 个源全部不可达时，回退到脚本内置的一批静态候选 IP，保证离线也能尝试。
   需要增加备选源，直接在脚本顶部 `IP_SOURCES` 里按行添加 URL 即可。
2. **逐个测试**：对每个候选 IP 用 `--resolve` 真实请求翻译接口，只保留能返回译文的 IP，
   记录响应耗时；最多测试 18 个，找到 3 个可用即提前结束（控制真机耗时）。
3. **写入 hosts**：按耗时排序，**最快的作为生效行**写入 `/etc/hosts`，其余可用 IP
   记为 `# backup ...` 注释备用；每次执行先清掉本工具旧规则，不污染其它 hosts 内容。
   结束时在屏幕显示选中的 IP、耗时与可用数量。

> 该脚本依赖 `curl`（`/usr/bin/curl` 或 PATH 中），执行时需要 `mntroot rw`。

## 六、屏蔽更新：五个独立动作

| 动作 | 脚本 | 作用 |
|---|---|---|
| 屏蔽更新 | `block-ota/rename.sh` | 重命名 `otaupd/otav3`、写占位二进制、删除已下载升级包，然后 `reboot` |
| 恢复更新 | `block-ota/restore.sh` | 还原 `otaupd/otav3` 备份，然后 `reboot` |
| 锁定更新 | `backdoorlock/lock.sh` | 劫持 `/etc/updater.conf` 的 `_UPDATE_WAIT`、注释 OTA 处理器 |
| 解锁更新 | `backdoorlock/unlock.sh` | 还原 `updater.conf` 与 OTA 处理器 |
| 删除更新 | `backdoorlock/delete.sh` | 删除 `/mnt/us/update*.bin`、`Update*.bin`、`FWUO*.partial`（保留防重启占位文件） |

两个方案互相独立、可单独开关。`backdoorlock` 依赖的 `updatewait` 占位文件已随插件置于
`helper/backdoorlock/updatewait`（可执行）。五个动作都带 Waiting / Done 反馈；
屏蔽与恢复更新在重启前会停留 2 秒显示结果，便于看清状态。

## 七、检查更新

`github_update.sh` → `github_update.py`：通过 GitHub API 查最新 Release → 与本地 `VERSION`
比对 → **仅当确实有新版本时**才下载 asset 并解压覆盖到扩展目录；已是最新则只提示，不下载。
逐行显示版本状态（如 `Already up-to-date: v1.8.0` / `Downloading update package...` /
`Updated to v1.x.x - please refresh KUAL menu`），首尾各有 Waiting / Done 提示。

- `bin/config.sh` 已指向正式仓库 `Gh9518/kual-helper`，资产名 `helper.zip`；
- 匿名 API 被限流时用 `/releases/latest` 网页重定向兜底，下载失败自动重试一次；
- 插件内不需要任何 token。

## 八、使用方法

把解压后的 `helper/` 复制到 Kindle 的 `/mnt/us/extensions/`，打开 KUAL 即出现 **Helper** 菜单。

## 九、v1.8.0 执行链修复与本轮校验

**为什么会「每一项点击后都无反应」**：v1.7.0 的菜单用相对 `./bin/...` 调用脚本，脚本内部
又用 `. ./bin/config.sh` / `. ./bin/msg.sh` 加载依赖，整套链路默认 KUAL 执行时的工作目录
就是插件目录；同时隐含要求脚本带可执行位、shebang 能被正确解析。任一条件不满足，动作
就会静默失败。对照最初上传的原始插件：能正常工作的屏保脚本是零依赖的极简 `lipc` 调用，
BlockKindleOTA / backdoorlock 的菜单也只有 `name / priority / action / exitmenu` 四个字段。

**修复**
- `menu.json`：17 个 `action` 全部改为 `/bin/sh /mnt/us/extensions/helper/bin/...`，
  删除 `checked` 与 `internal`，保留 `status:false`。
- 全部 14 个 `.sh` 加入 `KUAL_HOME` 自定位（从 `$0` 真实路径向上找 `config.xml`），
  `config.sh` / `msg.sh` / Python 入口一律改成 `$KUAL_HOME/bin/...` 绝对路径。
- 依赖加载加 fallback：`config.sh` 或 `msg.sh` 不可读时定义最小反馈函数，避免 POSIX `sh`
  因 `.` 失败直接终止。
- 去掉非 POSIX 写法（`source` / `&>` / `==` / `local`），并修复去掉 `local` 后
  `do.sh` 中 `bak` 被当成命令的回归。
- 屏保 / 商店四个菜单常驻独立且不带 `checked`，不再出现「同时选中」的假状态。

**校验**
- `menu.json` JSON 合法；4 个一级菜单名为中文；全部 `priority ≥ 1000`；
  17 个 `action` 全部为绝对路径且显式 `/bin/sh`；无 `checked`、无 `internal`。
- 全部 `.sh` 与 `updatewait` 通过 `sh -n`，全部 `.py` 通过编译检查，无 BOM / CRLF。
- **真机语义桩测 17/17**：从 `cwd='/'` 执行、脚本设为 `644` 无可执行位、不注入
  `KUAL_HOME` / `KINDLE_PATH` / `KUAL_EIPS`，系统命令用 mock。17 个动作全部产生
  `Waiting...` 与 `Done:` 反馈且无 `Failed:`；并逐项断言副作用：
  屏保 `preventScreenSaver 1/0`、商店 `search_bar.js` 改写与还原（含 `.KUAL_bak`）、
  日志删除、`/etc/hosts` 写入最快 IP、OTA 二进制改名与还原、backdoorlock 配置劫持与
  还原、更新包删除、更新检查执行。
