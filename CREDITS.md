# 致谢与来源 / Credits & Acknowledgements

本插件是一次**个人学习性质的整合与再创作**：把多个 KUAL 扩展收拢到单一 `helper` 菜单，
并做扩展、修复与加固。下列条目是本项目**实际用到或参考过**的项目、标准与服务，
每条按「名称 — 用途 — 许可证 — 链接」一行列出。各上游版权与许可归其原作者所有，
本整合版仅作整理与个人使用，不改变上游授权关系。功能重叠但**未保留实现**的项目已从致谢中删除，
避免清单变成噪音。

## 项目与标准 / Projects & standards

- BookFere Tools（书伴 / bookfere.com）— 核心骨架：Python 探测与 eips 提示、fix-cover 系列、sdr-cleaner、fix-google-translate、更新器设计 — 上游未声明（版权归原作者）— https://bookfere.com
- 书伴教程《修复封面》（post/994）— 缩略图机制、日志命名与封面修复依据 — 站点版权 — https://bookfere.com/post/994.html
- KUAL（Kindle Unified Application Launcher）— config.xml + menu.json 扩展机制与 RPN if 条件（屏保 / 商店互斥开关）— 上游未声明 — https://www.mobileread.com/forums/
- KUAL-add-ons `do.sh`（stepk 著 / NiLuJe 维护）— 商店按钮替换与 KUAL 缓存清理函数 — 见上游声明 — https://www.mobileread.com/forums/
- 原 `helper` 扩展（ssprevent.sh / ssallow.sh 等）— 屏保开关与早期 OTA 屏蔽脚本 — 上游未声明 — https://www.mobileread.com/forums/
- BlockKindleOTA — 重命名 otaupd/otav3 并写占位脚本的物理屏蔽方案 — 上游未声明 — https://www.mobileread.com/forums/
- backdoorlock — 劫持 /etc/updater.conf 的配置层屏蔽方案 — 上游未声明 — https://www.mobileread.com/forums/
- hcfyapp/google-translate-cn-ip — 「修复谷歌」所用的 Google 翻译可用 IP 列表源 — 见上游仓库 — https://github.com/hcfyapp/google-translate-cn-ip
- KindleUnpack（kevinhendricks）/ DualMetaFix — MOBI/AZW 容器解析与封面提取（mmap 低内存改造为本项目自主适配）— GPL-3.0 — https://github.com/kevinhendricks/KindleUnpack
- Open Library / Google Books / Amazon / 豆瓣 — 「联网修复封面」的四个备选数据源 — 各服务条款 — https://openlibrary.org
- libmobi（bfabiszewski）— 资源成对释放 / 错误码逐调用检查的范式参考（仅借鉴思路，未引入代码）— LGPL-3.0-or-later — https://github.com/bfabiszewski/libmobi
- Python `mmap` 官方文档 — 封面 OOM 修复所用只读映射 API 的硬约束依据 — PSF License — https://docs.python.org/3/library/mmap.html
- AWS Builders' Library（timeouts / retries / backoff）— 联网重试上限与超时的设计参考（仅借鉴思路）— © Amazon（仅思路参考）— https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/
- Keep a Changelog 1.1.0 — 本变更日志的格式规范 — CC BY-SA 3.0 — https://keepachangelog.com/en/1.1.0/
- Conventional Commits 1.0.0 — 提交信息格式规范 — CC BY 3.0 — https://www.conventionalcommits.org/en/v1.0.0/

## 整理者说明 / Maintainer note

整合、扩展、缺陷修复与文档由本仓库维护。若任何上游作者认为本整合版的使用方式不妥，
欢迎通过仓库 Issue 联系，将及时更正或移除相关内容。
