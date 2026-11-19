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

# 清理无用 SDR 文件夹 / 截图（不带日志）。
# 运行中提示与结束提示由 bin/msg.sh 统一给出。

if [ -r "$KUAL_HOME/bin/config.sh" ]; then
    . "$KUAL_HOME/bin/config.sh"
else
    KINDLE_PATH=/mnt/us
    PYTHON3=$(command -v python3 2>/dev/null)
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
