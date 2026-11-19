# 技术债 / Tech Debt（本轮发现但超出范围，未改动）

> 本轮（v1.11.x 优化）遵循「最小 diff、不动无关代码」原则。以下问题经评估属于
> 低风险或需要改变既有行为/契约，本轮只记录，不实施。按优先级与影响排序。

## 稳定性 / 健壮性

- `bin/github_update.sh:40` 用固定前缀 `/tmp/kual_upd_msg_$$` 存 Python 输出，正常路径末尾 `rm -f`；
  但脚本自身未设 EXIT trap，若被信号中断会残留一个临时文件。影响极小（文件名带 PID、重启后系统清理 /tmp），
  且加 trap 会牵动引导链，本轮不动。建议后续版本统一加 `_cleanup` trap。
- `bin/sdr-cleaner/sdr_cleaner.py:60` `clean_shots()` 的 `os.listdir(kindle_path)` 未包 try/except；
  若根目录被卸载或权限异常会抛 traceback。调用方 `onProcess` 只校验了 `documents` 子目录存在，
  未校验根目录本身。真机上 `/mnt/us` 恒存在，风险低；改动会改变异常时的输出格式，本轮不动。
- `bin/fix-cover/CoverNet.py` 多处 `except Exception: pass`（如 `_pick_google`/`fetch_image`）。
  这是「多 provider 容错」的有意设计（一个源失败就试下一个），吞异常符合语义；但若未来要诊断
  具体网络错误，应改为记录到可选 logger 而非静默。本轮不改，以避免在设备 Python 上引入日志开销。

## 重试 / 退避

- `bin/github_update.py:211` 下载重试为「立即重试一次、无退避、无抖动」。参考 AWS Builders'
  Library 的建议应加指数退避 + 抖动，但设备端只需 2 次尝试，且加随机抖动会让行为不可预测、
  桩测难以复现。本轮保留现状；若后续弱网失败率上升再加 `sleep 1`/`sleep 2` 的固定短退避即可。

## 结构 / 可维护性

- 13 个动作脚本仍各自保留约 13 行的「引导头 source common.sh」样板。v1.11.0 已把真正的
  逻辑收敛到 common.sh，这部分是 KUAL 直接执行入口所必需的（每个 action 是独立 `/bin/sh` 进程），
  无法再消除，属合理样板，非技术债。

## 易用性

- 屏幕提示（eips）受固化 ASCII 字体限制只能用英文，中文细节留在运行日志与 README。
  这是设备字体约束，非代码问题。
