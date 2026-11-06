#!/bin/sh

# 由 $0 的真实路径定位插件根目录（向上查找 config.xml），不依赖调用方的工作目录；
# 找不到时回退到标准安装路径。KUAL_HOME 可由测试环境覆盖。
_kh=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || _kh=''
case "$_kh" in ''|/) _kh=/mnt/us/extensions/helper ;; esac
while [ "$_kh" != / ] && [ ! -f "$_kh/config.xml" ]; do _kh=$(dirname "$_kh"); done
[ -f "$_kh/config.xml" ] || _kh=/mnt/us/extensions/helper
KUAL_HOME=${KUAL_HOME:-$_kh}

# 清理无用 SDR 文件夹 / 截图（不带日志）。
# 运行中提示与结束提示由 bin/msg.sh 统一给出。

if [ -r "$KUAL_HOME/bin/config.sh" ]; then
    . "$KUAL_HOME/bin/config.sh"
else
    KINDLE_PATH=/mnt/us
    PYTHON3=$(command -v python3 2>/dev/null)
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
fi

SHOT=0
for a in "$@"; do
    case "$a" in
        --shot) SHOT=1 ;;
    esac
done

if [ "$SHOT" -eq 1 ]; then
    msg_wait "Cleaning screenshots"
else
    msg_wait "Cleaning unused SDR folders"
fi

RESULT=''
if [ -f "$PYTHON2" ]; then
    RESULT=$($PYTHON2 $SDR_SCRIPT "$@" 2>&1)
    rc=$?
elif [ -f "$PYTHON3" ]; then
    RESULT=$($PYTHON3 $SDR_SCRIPT "$@" 2>&1)
    rc=$?
else
    msg_fail "Python not found on Kindle"
    exit 0
fi

if [ "$rc" -ne 0 ]; then
    msg_fail "Cleaner error (rc=$rc)"
elif [ -n "$RESULT" ]; then
    msg_ok "$RESULT"
else
    msg_ok "Clean finished"
fi
