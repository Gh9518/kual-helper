# 致谢与来源 / Credits & Acknowledgements

本插件是一次**个人学习性质的整合与再创作**：把多个 KUAL 扩展的功能收拢到单一 `helper`
菜单下，并按使用习惯重新组织、修复与加固。它建立在以下项目作者与社区的思路和代码之上，
在此诚挚致谢。各项目的版权与许可均归其原作者所有；本整合版仅作整理与个人使用，未改变
各上游项目的授权关系。

## 一、书伴平台（bookfere.com / BookFere，早期署名 KindleFere）— 特别感谢

书伴是本项目最主要的思路与代码来源，也是 Kindle 中文玩家最重要的资料站之一：

- **BookFere Tools**（`bookfere-tools`）提供了本插件的核心骨架：`config.sh` 的 Python
  探测与 `eips` 提示框架、`fix-cover` 系列（`FixCover.py` / `File.py` / `KindleUnpack.py` /
  `DualMetaFix.py`，用于从 MOBI/AZW 容器提取内嵌封面）、`sdr-cleaner`（清理无用 SDR
  文件夹与截图）、`fix-google-translate`（修改 hosts 恢复谷歌翻译 API）、以及版本更新的
  设计思路。本整合版在这些代码上做了扩展（EPUB/PDF 封面、联网多源封面、从 GitHub
  自动获取并测速谷歌翻译 IP 等）与缺陷修复。
- **教程与资料**：封面修复功能沿用了书伴的反馈页
  [`bookfere.com/post/994.html`](https://bookfere.com/post/994.html)，其关于 Kindle
  缩略图、`/mnt/us/documents` 与 `system/thumbnails` 关系、崩溃日志命名的说明，
  是本插件实现「封面修复」「清理日志」的重要依据。
- **原始更新日志**：插件内的 `helper/ChangeLog.txt` 完整保留了 BookFere Tools
  2016–2022 年的更新记录，作为溯源与致敬，未作删改。

感谢书伴及其作者长期、无偿地维护这些工具与中文 Kindle 教程资源。

## 二、KUAL 及其社区扩展

- **KUAL（Kindle Unified Application Launcher）** 及 MobileRead 社区贡献者：提供了
  `config.xml` + `menu.json` 的扩展机制与 `if` RPN 条件表达式（互斥开关、型号判断、
  文件判断等），本插件的「屏保开关」「商店开关」正是基于该机制实现。
- **KUAL-add-ons / add-ons 处理器**（`do.sh`，源码署名 **stepk**，并经 **NiLuJe**
  维护，`$Id: do.sh 13380 ... NiLuJe $`）：本插件直接复用了其中的
  `toggle_store_button`（商店按钮替换/恢复）、`purge_KUAL_cache` 等函数。
- **原 `helper` 扩展**：`ssprevent.sh` / `ssallow.sh`（屏保开关）、早期 OTA 屏蔽脚本等，
  是本插件「系统工具」与「屏蔽更新」菜单的原始动作来源。
- **KUAL 自带的 Helper 菜单与 `Install MR Packages`**：由 MRPI（MobileRead Package
  Installer）生态自动注入，本插件不再重复内置，仅通过 `priority` 保证自身菜单排在其下。

## 三、屏蔽系统更新的方案作者

- **BlockKindleOTA**：重命名 `otaupd` / `otav3` 并写入占位脚本的物理屏蔽方案。
- **backdoorlock**：劫持 `/etc/updater.conf` 的 `_UPDATE_WAIT`、注释 OTA 处理器的
  配置层屏蔽方案。
- **renameotabin** 等：提供了同类的 OTA 屏蔽思路（因与 BlockKindleOTA 功能重叠，
  整合时未保留其实现，但思路被借鉴与对比）。

感谢这些作者提供的两种互补、可独立开关的屏蔽思路。

## 四、网络数据与第三方服务

- **hcfyapp/google-translate-cn-ip**：`修复谷歌` 功能所用的 `translate.googleapis.com`
  国内可用 IP 列表源（[github.com/hcfyapp/google-translate-cn-ip](https://github.com/hcfyapp/google-translate-cn-ip)），
  本插件通过其 GitHub / CDN 多地址自动取回并逐个测速。
- **Open Library、Google Books、Amazon、豆瓣**：`联网修复封面` 的四个备选封面数据源，
  采用「任一成功即止」的多源回退设计。
- **KindleUnpack / DualMetaFix**（MobileRead 社区的 MOBI 解析代码）：使从 AZW/MOBI
  容器内提取封面成为可能。

## 五、整理者说明

整合、扩展、缺陷修复与文档由本仓库维护。若任何上游作者认为本整合版的使用方式不妥，
欢迎通过仓库 Issue 联系，将及时更正或移除相关内容。

---

### English

This is a **personal, learning-oriented consolidation** of several KUAL extensions into a
single `helper` menu. It stands on the ideas and code of the projects below; all copyrights
and licenses remain with their respective authors.

- **Special thanks to 书伴 / BookFere (`bookfere.com`, formerly KindleFere)** — the main
  source of both code and know-how: BookFere Tools supplied the `config.sh` framework, the
  `fix-cover` toolchain (MOBI/AZW cover extraction via KindleUnpack / DualMetaFix),
  `sdr-cleaner`, the hosts-based Google Translate fix, and the tutorial at
  `bookfere.com/post/994.html`. The original 2016–2022 `ChangeLog.txt` is kept verbatim.
- **KUAL** and its MobileRead contributors — the `config.xml` / `menu.json` extension model
  and the RPN `if` conditionals used by the screensaver/store toggles.
- **KUAL-add-ons `do.sh`** (by **stepk**, maintained by **NiLuJe**) — store-button toggle
  and cache purge helpers.
- **The original `helper` extension** — screensaver and OTA scripts.
- **BlockKindleOTA**, **backdoorlock**, **renameotabin** — the two complementary OTA-blocking
  approaches retained here.
- **hcfyapp/google-translate-cn-ip** — the community-maintained IP list for Google Translate.
- **Open Library / Google Books / Amazon / Douban** — fallback cover sources.
- **KindleUnpack / DualMetaFix** (MobileRead community) — MOBI container parsing.
