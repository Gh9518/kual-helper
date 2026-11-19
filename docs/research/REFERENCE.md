# 参考资料与借鉴清单（阶段 1）

> 检索日期：2026-11-20。目标平台：Kindle Paperwhite 4（pw4 / juno-rex，第 10 代，2018）。
> 本清单遵循固定格式：`- 结论 — 来源 URL — 许可证 — 是否可商用引用`。
> **「是否可商用引用=否」的条目，后续阶段一律只抄思路、不搬运代码。**

## 一、平台硬约束（依据原始资料，非猜测）

- pw4 = Paperwhite 第 10 代（2018），代号 juno/rex，SoC 为 NXP i.MX6SLL / ARM Cortex-A9，架构 armv7l（ARMv7-A），单核，主频 396/996 MHz — https://github.com/dalager/kindle-todo/blob/main/docs/devices/paperwhite_10gen.md — 仓库未见明确 LICENSE（仅思路参考） — 否
- pw4 内存 512 MB RAM + 128 MB zram 交换，用户分区 /mnt/us 约 6.2 GB；根分区只读约 493 MB — http://www.mobileread.org/forums/showthread.php?p=4518868 — 论坛帖（用户生成内容） — 否
- pw4 常见固件为 5.18.1.1.1；jailbreak 后 KPM 可安装 Python 3.10 到 /var/local，设备原生即具备 Python 运行时 — https://www.afeige.com/en/project/kindle-jailbreak — 站点未声明许可证 — 否
- 本项目为纯 shell + Python 脚本，无编译产物、无静态/动态链接步骤，因此「静态链接 / armel-armhf ABI 匹配」条款不适用；脚本由设备解释器执行，ABI 由解释器负责，只要不引入原生扩展即无 ABI 风险 — https://www.python.org/dev/peps/pep-0211/ — PSF License — 是
- Kindle 根分区可写需 `mntroot rw`，操作后必须 `mntroot ro` 恢复；写 /mnt/us 用户分区无需切换 — http://www.mobileread.org/forums/showthread.php?p=4518868 — 论坛帖（用户生成内容） — 否

## 二、同类成熟实现对比（≥2 个，均为真实 GitHub 项目）

### 2.1 KindleUnpack（kevinhendricks）

- `Sectionizer.__init__` 用 `with open(...,'rb') as f: self.data = f.read()` 全文件读入，`loadSection()` 返回切片；句柄由 with 自动关闭 — https://github.com/kevinhendricks/KindleUnpack/blob/master/lib/mobi_sectioner.py — GPL-3.0（COPYING.txt） — 否
- **重要事实（避免错误致谢）**：上游自身仍是全文件读入、并非 mmap，因此本项目 v1.10.1 的 mmap 改造是为 512MB 内存设备做的自主适配，不是从本项目搬运；借鉴的仅为「用 with 托管文件句柄」这一资源管理方式 — https://github.com/kevinhendricks/KindleUnpack/blob/master/lib/mobi_sectioner.py — GPL-3.0 — 否
- 错误处理：自定义 `unpackException`，解析失败显式抛异常而非静默返回；越界访问用打印提示（`setsectiondescription`）— https://github.com/kevinhendricks/KindleUnpack/blob/master/lib/mobi_sectioner.py — GPL-3.0 — 否
- 配置管理：偏好从 ini 迁到 json，命令行参数用 argparse 风格集中定义（`-r -s -d -h -i`）— https://github.com/kevinhendricks/KindleUnpack — GPL-3.0 — 否

### 2.2 libmobi（bfabiszewski）

- 资源释放范式：`mobi_init()` 后每个失败分支都 `mobi_free(m)`，`mobi_free_rawml()` 与 `mobi_free()` 成对调用；`fopen`/`fclose` 紧跟 `mobi_load_file`，句柄生命周期短 — https://github.com/bfabiszewski/libmobi — LGPL-3.0-or-later（Debian copyright: LGPL-3+） — 否
- 错误处理范式：所有 API 返回 `MOBI_RET` 枚举，`MOBI_SUCCESS` 之外的码逐调用检查，不吞异常；本项目可借鉴「每个外部解析动作返回明确结果并成对释放」的结构，但只抄思路 — https://packages.debian.org/trixie/libmobi-dev — LGPL-3.0-or-later — 否
- 明确声明「works cross-compiled on Kindle」，且承认 Huffman/KF8 算法源自 KindleUnpack；作为「同类功能可在 pw4 上稳定运行」的佐证 — https://github.com/bfabiszewski/libmobi — LGPL-3.0-or-later — 否
- 该 C 库为原生二进制，需要交叉编译与 ABI 匹配；本项目不引入它，正因为它是 LGPL 原生库且会破坏「纯脚本、免 ABI」的约束 — https://github.com/bfabiszewski/libmobi — LGPL-3.0-or-later — 否

### 2.3 对比结论（本项目该借鉴什么）

| 维度 | KindleUnpack | libmobi | 本项目现状 / 借鉴决策 |
|---|---|---|---|
| 错误处理 | 自定义异常 + 显式抛 | `MOBI_RET` 逐调用检查 | 已有 START/OK/FAIL 日志；借鉴「失败必须带原因码」，不吞异常 |
| 资源释放 | with 托管句柄，但整本数据常驻 | init/free 成对，失败分支也 free | v1.10.1 mmap+close、v1.11.0 try/finally；借鉴 libmobi「失败路径也要释放」的成对检查 |
| 配置管理 | ini→json、CLI 集中定义 | autotools 选项 | 本项目 config.xml + menu.json + common.sh 集中；保持格式契约不变，不引入新配置文件 |

## 三、语言 / 框架 / 协议的官方规范与硬约束条款

### 3.1 Python `mmap`（本项目封面 OOM 修复的核心依赖）

- `mmap.close()` 后对对象其它方法的调用抛 `ValueError`，且 close 不会关闭底层文件对象 — https://docs.python.org/3/library/mmap.html — PSF License — 是
- `ACCESS_READ` 只读映射的赋值/写入/move/resize 均抛 `TypeError`；本项目只读解析应使用 ACCESS_READ 以防误写 — https://docs.python.org/3/library/mmap.html — PSF License — 是
- 切片读取返回字节串（`mm[:5]` → `b'Hello'`）；映射可当 `bytearray` 用 — https://docs.python.org/3/library/mmap.html — PSF License — 是
- 可用 `with mmap.mmap(...)` 作上下文管理器自动释放；若用 `os.open()` 得到的 fd 仍需调用方关闭 — https://docs.python.org/3/library/mmap.html — PSF License — 是
- 对可写缓冲文件映射前应先 `flush()`；不 flush 则改动写回无保证 — https://docs.python.org/3/library/mmap.html — PSF License — 是

### 3.2 超时 / 重试 / 退避（本项目联网功能：检查更新、修复谷歌）

- 重试必须有最大次数上限，避免无限循环；无上限重试会放大故障 — https://docs.aws.amazon.com/zh_cn/prescriptive-guidance/latest/cloud-design-patterns/retry-backoff.html — AWS 文档（© Amazon，仅思路参考） — 否
- 退避应指数增长并加抖动（full jitter: random(0, capped exponential)），避免同步重试风暴 — https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/ — AWS 文档（© Amazon，仅思路参考） — 否
- 应区分「可重试」（网络抖动、429/503/504）与「不可重试」（400、认证失败）；超时属于「结果未知」，需先核对而非盲目重试 — https://aws.amazon.com/builders-library/making-retries-safe-with-idempotent-APIs/ — AWS 文档（© Amazon，仅思路参考） — 否
- 每次尝试设显式超时，整体设 deadline，二者分离 — https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/ — AWS 文档（© Amazon，仅思路参考） — 否
- 本项目设备端更新器已有「弱网重试一次 + 90s 超时 + 下载大小上限」，符合「上限+超时+可重试分类」的硬约束；本轮不引入随机抖动以免改变可预测行为（记录到 tech-debt） — https://docs.aws.amazon.com/zh_cn/prescriptive-guidance/latest/cloud-design-patterns/retry-backoff.html — AWS 文档 — 否

### 3.3 文档与提交规范（阶段 4 直接使用）

- Keep a Changelog 1.1.0：顶部保留 `[Unreleased]`，变更类型 Added/Changed/Deprecated/Removed/Fixed/Security；只写用户可感知变化，不写内部重构噪音 — https://keepachangelog.com/en/1.1.0/ — CC BY-SA 3.0（站点声明；仅格式参考） — 是
- Keep a Changelog：日期用 ISO 8601（YYYY-MM-DD），最新在前，每个版本一个条目 — https://keepachangelog.com/en/1.1.0/ — CC BY-SA 3.0 — 是
- Conventional Commits 1.0.0：格式 `<type>[scope]: <description>`，允许 `fix/feat/docs/refactor/perf/test` 等类型；scope 为描述代码区块的名词 — https://www.conventionalcommits.org/en/v1.0.0/ — CC BY 3.0（站点声明；仅格式参考） — 是
- Conventional Commits：`fix` 对应 PATCH、`feat` 对应 MINOR、含 `BREAKING CHANGE` 对应 MAJOR；无破坏性变更时不应写 footer — https://www.conventionalcommits.org/en/v1.0.0/ — CC BY 3.0 — 是

## 四、发布时间标注

| 资料 | 性质 / 时间 | 处理 |
|---|---|---|
| kindle-todo 设备探测（juno/rex） | 2026-07 真机 SSH 探测（近 1 年） | 平台事实，仅思路 |
| afeige PW4 jailbreak 记录 | 2026-06-30 发布（近 1 年） | 固件/Python 佐证，仅思路 |
| libmobi | 上游 0.12（2024-06），Debian trixie 收录 | 版本略旧但稳定，仅抄范式 |
| KindleUnpack | 长期维护，COPYING GPL-3.0 | 许可证明确，仅抄范式 |
| Python mmap 官方文档 | 持续更新，访问于 2026-11-20 | 官方硬约束，可商用引用 |
| AWS retry/backoff 文档 | Amazon Builders' Library，访问于 2026-11-20 | 仅思路，不商用引用 |
| Keep a Changelog 1.1.0 / Conventional Commits 1.0.0 | 规范冻结版（2019 / 2023） | 标准格式，可商用引用 |

## 五、后续阶段禁运清单

以下来源标记为「不可商用引用」，阶段 2 只借鉴思路，不复制其代码：
KindleUnpack 源码、libmobi 源码、kindle-todo 站点、afeige 站点、MobileRead 论坛帖、AWS Builders' Library 原文。
可直接引用规范文本/格式的：Python 官方文档（PSF）、Keep a Changelog（CC BY-SA）、Conventional Commits（CC BY）。

```
[PHASE 1 DONE]
```
产物路径：`/workspace/docs/research/REFERENCE.md`
