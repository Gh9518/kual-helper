#!/bin/sh

# 由 $0 的真实路径定位插件根目录（向上查找 config.xml），不依赖调用方的工作目录；
# 找不到时回退到标准安装路径。KUAL_HOME 可由测试环境覆盖。
_kh=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || _kh=''
case "$_kh" in ''|/) _kh=/mnt/us/extensions/helper ;; esac
while [ "$_kh" != / ] && [ ! -f "$_kh/config.xml" ]; do _kh=$(dirname "$_kh"); done
[ -f "$_kh/config.xml" ] || _kh=/mnt/us/extensions/helper
KUAL_HOME=${KUAL_HOME:-$_kh}

# 清理日志：删除 USB 可见区（/mnt/us）内的所有日志文件，以及 Kindle 5.16.x+
# 生成的 4 类崩溃日志 / 转储文件：
#   ① Indexer_Dump*   ② cvm_*（…juno…）  ③ KPPMainApp*   ④ Mesquite*
# 并一并清理同类崩溃变体（*_crash_*、*.core、indexer*.dump* 等）。
# 只按「文件名」匹配、大小写不敏感；结果同时在屏幕与插件运行日志中留痕。
# 注意：插件自身的运行日志目录（$KUAL_HOME/logs）由 bin/log.sh 的 3 天保留策略管理，
#       本功能会跳过它，避免「清理日志」把刚产生的运行日志删掉。

if [ -r "$KUAL_HOME/bin/msg.sh" ]; then
    . "$KUAL_HOME/bin/msg.sh"
else
    _log_write() { return 0; }
    [ -n "$KUAL_HOME" ] && [ -r "$KUAL_HOME/bin/log.sh" ] && . "$KUAL_HOME/bin/log.sh"
    _eips=$(command -v eips 2>/dev/null)
    msg_show() { [ -n "$_eips" ] && "$_eips" 2 "$1" "$2" >/dev/null 2>&1; printf '[KUAL] %s\n' "$2" >&2; }
    msg_wait() { msg_show 3 "Waiting... $*"; _log_write START "$*"; }
    msg_info() { msg_show 3 "$*"; _log_write INFO "$*"; }
    msg_ok()   { msg_show 4 "Done: $*"; _log_write OK "$*"; }
    msg_fail() { msg_show 4 "Failed: $*"; _log_write FAIL "$*"; }
fi

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
