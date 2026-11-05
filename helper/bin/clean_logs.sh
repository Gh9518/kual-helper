#!/bin/sh
# 清理日志：删除 USB 可见区（/mnt/us）内的所有日志文件，以及 Kindle 5.16.x+
# 生成的 4 类崩溃日志 / 转储文件：
#   ① Indexer_Dump*   ② cvm_*（…juno…）  ③ KPPMainApp*   ④ Mesquite*
# 并一并清理同类崩溃变体（*_crash_*、*.core、powerd_*/cmd_* 等）。
# 只按「文件名」匹配、大小写不敏感；不写任何日志文件，结果只在屏幕提示。

US_ROOT=${US_ROOT:-/mnt/us}

eips_msg() {
    if [ -x /usr/sbin/eips ]; then
        /usr/sbin/eips 2 3 "$1" >/dev/null 2>&1
    else
        eips 2 3 "$1" >/dev/null 2>&1
    fi
}

if [ ! -d "$US_ROOT" ]; then
    eips_msg "无法访问 $US_ROOT"
    exit 0
fi

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
    eips_msg "已清理 $cnt 个日志/崩溃文件，释放约 ${mb}MB"
else
    eips_msg "没有发现日志文件"
fi
