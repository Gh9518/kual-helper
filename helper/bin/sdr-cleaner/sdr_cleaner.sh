#!/bin/sh
# 清理无用 SDR 文件夹 / 截图（不带日志）。
# 运行中提示与结束提示由 bin/msg.sh 统一给出。

. ./bin/config.sh

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
