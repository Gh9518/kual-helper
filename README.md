# KUAL Helper（单插件整合版 v1.6.0）

把原先分散在多个插件里的功能**全部整合为单一插件 `helper`**。安装文件夹名即 `helper`，
直接作为 KUAL 的 **Helper** 菜单出现。

- 正式仓库：**[github.com/Gh9518/kual-helper](https://github.com/Gh9518/kual-helper)**
- 中英双语发布说明：[RELEASE_NOTES.md](RELEASE_NOTES.md) ｜ 更新说明：[CHANGELOG.md](CHANGELOG.md) ｜ 致谢：[CREDITS.md](CREDITS.md)
- 菜单里的 `Check Update` 会自动连接上述仓库的最新 Release 检查并安装更新。

> 本版经过一轮完整代码审查与缺陷修复（详见 `CHANGELOG.md` 的「修复」项）。

## 一、菜单结构（全部扁平为一级动作，无日志）

```
Helper                     (priority -998)
├─ System Tools            (priority 1000)  系统工具
│   ├─ 禁用屏保 / 允许屏保  ssprevent.sh / ssallow.sh   ★互斥开关，只占 1 个菜单位
│   ├─ 屏蔽商店 / 恢复商店  do.sh toggle_store_button    ★互斥开关
│   ├─ 清理SDR             sdr_cleaner.sh --sdr         只清无用 SDR 文件夹
│   ├─ 清理截图            sdr_cleaner.sh --shot --no-sdr 只清截图
│   └─ 清理日志            clean_logs.sh                清理所有日志与崩溃转储
├─ Repair                  (priority 1010)  修复失效
│   ├─ 修复封面            fix_cover.sh                 离线修复所有电子书封面
│   ├─ 清理封面            fix_cover.sh --clean         清理所有无效封面文件
│   ├─ 联网修复封面        fix_cover.sh --net --missing-only  仅尝试无封面的电子书
│   └─ 修复谷歌            fix_google_translate.sh      GitHub 取 IP → 逐个测试 → 写 hosts
├─ Block Updates           (priority 1020)  屏蔽更新
│   ├─ 屏蔽更新            block-ota/rename.sh          BlockKindleOTA 开启
│   ├─ 恢复更新            block-ota/restore.sh         BlockKindleOTA 关闭并恢复
│   ├─ 锁定更新            backdoorlock/lock.sh         backdoorlock 开启
│   ├─ 解锁更新            backdoorlock/unlock.sh       backdoorlock 关闭并恢复
│   └─ 删除更新            backdoorlock/delete.sh       删除系统已有的更新文件
└─ Check Update            (priority 1030，单动作)  检查更新
    └─ github_update.sh    点击 → 检测版本 → 有新版本才下载安装
```

> 所有菜单项均**不带日志**：SDR、封面、backdoorlock、日志清理本身都不生成任何日志文件，
> 结果只在屏幕提示。

### 一级菜单名（本轮改为英语）

| 英语 | 原中文 |
|---|---|
| System Tools | 系统工具 |
| Repair | 修复失效 |
| Block Updates | 屏蔽更新 |
| Check Update | 检查更新 |

二级动作名保留中文（如需一并英文化，告诉我即可）。

## 二、Install MR Packages：不再内置，改用系统自动项

- 上一版内置的 `Install MR Packages`（`bin/install_mr.sh`）已**删除**——真机 KUAL/MRPI
  会**自动注入**这个按钮，无需插件重复提供，避免出现两个同名项。
- KUAL 菜单按 `priority` **升序**排列（数值越小越靠上）。自动注入的 `Install MR Packages`
  通常是小/负 priority；本插件 4 个菜单保持 `1000 / 1010 / 1020 / 1030`（大正数），
  因此**所有功能菜单仍严格排在其下方**，满足"排在 Install MR Packages 下面"的要求。

## 三、系统工具的两处归类调整

### 屏保：由两个菜单合并为一个互斥开关
原「禁用屏保」「允许屏保」是两个常驻菜单项。现改为与「屏蔽商店/恢复商店」相同的
**互斥开关**机制，视觉上始终只显示一个，等于少一个菜单：

- 状态标记文件 `/mnt/us/extensions/helper/.screensaver_disabled`；
- `禁用屏保` 带 `if: "标记" -f !`（标记不存在 → 显示），`允许屏保` 带 `if: "标记" -f`（标记存在 → 显示）；
- `ssprevent.sh`：设 `preventScreenSaver 1` 并**创建**标记 → 刷新后菜单变「允许屏保」；
- `ssallow.sh`：设 `preventScreenSaver 0` 并**删除**标记 → 刷新后菜单变回「禁用屏保」。

> `preventScreenSaver` 是运行时属性，Kindle 重启后会失效；而标记文件持久。若重启后菜单
> 仍显示「允许屏保」而屏保其实已恢复，点一次「允许屏保」即可让二者同步。

### 清理三项归到末尾
`清理SDR`、`清理截图`、`清理日志` 三个"清理"类动作集中在 **System Tools 的最后三位**
（priority 5/6/7），前面留给屏保、商店两个开关，分类更清晰。

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

另外一并清理同类变体：`*_crash_*.txt / .tgz / .sdr`（documents 下的崩溃报告）、
`*.core`（约 30MB 的大转储，如 `powerd_*`、`cmd_*`）、`Indexer*.dump*`，避免遗漏。

**安全性**
- 只按**文件名**匹配、大小写不敏感（`Indexer_Dump` 与 `indexer_dump` 都能清）；
- 不按内容或宽泛扩展名删除，电子书、普通文档、`DISABLE_CORE_DUMP` 等抑制文件均会保留；
- 不动系统分区（`/var/log` 等），自身也不写日志，只屏幕提示「清理 N 个、释放约 X MB」。
- 屏保状态标记 `.screensaver_disabled` 不匹配任何日志规则，不会被误删。

> 想从源头阻止崩溃日志再次生成，可在 U 盘根目录放一个**无扩展名**的空文件
> `DISABLE_CORE_DUMP`（可选再加 `DISABLE_CORE_DUMP_ALERT`）；本功能负责清理已产生的文件。

## 五、Repair：实现说明

### 修复封面（离线）
`fix_cover.sh` → `fix_cover.py`：从电子书**文件内嵌**的封面图提取并写回 Kindle 缩略图库，
覆盖 `.mobi / .azw / .azw3 / .azw4 / .epub / .pdf`（PDF 支持同目录 `书名.cover.jpg` 手动关联）。
完全离线，不联网。

### 清理封面（清理所有无效封面文件）
`fix_cover.sh --clean`：删除两类无效封面——
1. **孤立封面**：缩略图存在但已无对应电子书；
2. **损坏 / 占位封面**：小于 2KB 的空白缩略图。

### 联网修复封面（仅无封面的电子书）
`fix_cover.sh --net --missing-only`：新增 `--missing-only`，**已有正常封面的书直接跳过**，
只对「缩略图缺失或已损坏」的书尝试联网获取，避免无谓联网与流量。联网仅在内嵌封面确实
缺失时触发，多源回退顺序为：**Open Library → Google Books → Amazon → 豆瓣**，
任一成功即止；只接受合法 JPEG/PNG，丢弃 1×1 占位图，单源超时 6s 快速失败。

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

> 该脚本依赖 `curl`（`/usr/bin/curl` 或 PATH 中），执行时需要 `mntroot rw`。

## 六、Block Updates：五个独立动作

| 动作 | 脚本 | 作用 |
|---|---|---|
| 屏蔽更新 | `block-ota/rename.sh` | 重命名 `otaupd/otav3`、写占位二进制、删除已下载升级包，然后 `reboot` |
| 恢复更新 | `block-ota/restore.sh` | 还原 `otaupd/otav3` 备份，然后 `reboot` |
| 锁定更新 | `backdoorlock/lock.sh` | 劫持 `/etc/updater.conf` 的 `_UPDATE_WAIT`、注释 OTA 处理器 |
| 解锁更新 | `backdoorlock/unlock.sh` | 还原 `updater.conf` 与 OTA 处理器 |
| 删除更新 | `backdoorlock/delete.sh` | 删除 `/mnt/us/update*.bin`、`Update*.bin`、`FWUO*.partial`（保留防重启占位文件） |

两个方案互相独立、可单独开关。`backdoorlock` 依赖的 `updatewait` 占位文件已随插件置于
`helper/backdoorlock/updatewait`（可执行）。「删除更新」修复了原脚本 `&&` 前漏写 `cd`
导致 `rm` 从不执行的问题，现在会真正删除并给出屏幕提示。

## 七、Check Update

`github_update.sh` → `github_update.py`：通过 GitHub API 查最新 Release → 与本地 `VERSION`
比对 → **仅当确实有新版本时**才下载 asset 并解压覆盖到扩展目录；已是最新则只提示，不下载。

- 需在 `bin/config.sh` 把 `GITHUB_REPO` 从占位 `owner/helper` 改成你的真实仓库；
- 在 Release 上传名为 `helper.zip` 的更新包（顶层含 `helper/` 目录）。

## 八、使用方法

把解压后的 `helper/` 复制到 Kindle 的 `/mnt/us/extensions/`，打开 KUAL 即出现 **Helper** 菜单。

## 九、本轮校验

- `menu.json` JSON 合法；已删除内置 `Install MR Packages` 项与 `bin/install_mr.sh`；
  4 个一级菜单名为英语；全部 `priority ≥ 1000`（保证排在自动注入项之下）；
- 「无二级子菜单」、全部 `action` 路径存在均通过断言；
- 屏保互斥：用 RPN `if` 求值器验证「默认只显示禁用屏保 / 点击后只显示允许屏保」，
  两动作严格互斥；`ssprevent.sh`/`ssallow.sh` 状态文件的创建/删除与 lipc 属性 1/0 一致；
- System Tools 末三项恰为 `清理SDR / 清理截图 / 清理日志`；
- 所有 `.sh` 通过 `sh -n`、所有 `.py` 通过 `py_compile`，无日志落盘残留。
