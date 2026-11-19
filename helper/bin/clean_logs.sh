#!/bin/sh

# 公共引导：由 $0 向上定位并加载 common.sh（KUAL_HOME 定位 / 屏幕反馈 / 运行日志）。
# 找不到 common.sh 时仅降级屏幕反馈，主动作不受影响。
_b=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || _b=''
while [ -n "$_b" ] && [ "$_b" != / ] && [ ! -f "$_b/common.sh" ]; do _b=$(dirname "$_b"); done
if [ -f "$_b/common.sh" ]; then
    . "$_b/common.sh"
else
    msg_wait(){ :; }; msg_info(){ :; }; msg_ok(){ :; }
    msg_fail(){ printf '[KUAL] FAILED: %s\n' "$*" >&2; }
fi
unset _b

# 清理日志：删除 USB 可见区（/mnt/us）内的所有日志文件，以及 Kindle 5.16.x+
# 生成的 4 类崩溃日志 / 转储文件：
#   ① Indexer_Dump*   ② cvm_*（…juno…）  ③ KPPMainApp*   ④ Mesquite*
# 并一并清理同类崩溃变体（*_crash_*、*.core、indexer*.dump* 等）。
# 只按「文件名」匹配、大小写不敏感；结果同时在屏幕与插件运行日志中留痕。
# 注意：插件自身的运行日志目录（$KUAL_HOME/logs）由 bin/log.sh 的 3 天保留策略管理，
#       本功能会跳过它，避免「清理日志」把刚产生的运行日志删掉。

# 屏幕反馈与运行日志已由 common.sh 统一加载（见 bin/common.sh）。
:

US_ROOT=${US_ROOT:-/mnt/us}

if [ ! -d "$US_ROOT" ]; then
    msg_fail "Cannot access $US_ROOT"
    exit 0
fi

msg_wait "Cleaning log and crash files"

# 判断文件名是否属于「日志 / 崩溃日志」，统一转小写后匹配（大小写不敏感）
is_log_file() {
    n=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    case "$n" in
        # 所有普通日志文件（含轮转日志）
        *.log | *.log.* | *.trace | *.logfile) return 0 ;;
        # Kindle 4 类崩溃日志
        indexer_dump*)  return 0 ;;   # ① Indexer_Dump_1727406757193.txt
        cvm_*)          return 0 ;;   # ② cvm_...juno...
        kppmainapp*)    return 0 ;;   # ③ KPPMainApp / KPPMainAppV2
        mesquite*)      return 0 ;;   # ④ Mesquite
        # 同类崩溃 / 转储变体，避免遗漏
        *_crash_*)      return 0 ;;   # *_crash_*.txt / .tgz / .sdr
        *.core | *.core.gz | indexer*.dump*) return 0 ;;  # core dump
        *) return 1 ;;
    esac
}

# 扫描 USB 可见区（根目录、documents、extensions、system…，深度 3）
LIST=/tmp/kual_logclean_$$
find "$US_ROOT" -maxdepth 3 -type f > "$LIST" 2>/dev/null
[ -s "$LIST" ] || find "$US_ROOT" -type f > "$LIST" 2>/dev/null

cnt=0
bytes=0
while IFS= read -r f; do
    [ -n "$f" ] || continue
    # 豁免插件自身运行日志目录：由 bin/log.sh 按 3 天策略管理
    case "$f" in
        "$KUAL_HOME"/logs/* | */extensions/helper/logs/*) continue ;;
    esac
    is_log_file "${f##*/}" || continue
    sz=$(stat -c %s "$f" 2>/dev/null) || sz=0
    case "$sz" in ''|*[!0-9]*) sz=0 ;; esac
    if rm -f "$f" 2>/dev/null; then
        cnt=$((cnt + 1))
        bytes=$((bytes + sz))
    fi
done < "$LIST"
rm -f "$LIST"

mb=$(awk "BEGIN{printf \"%.1f\", $bytes/1048576}")
if [ "$cnt" -gt 0 ]; then
    msg_ok "$cnt log/crash file(s) removed, ${mb} MB freed"
else
    msg_ok "No log or crash files found"
fi
