#!/bin/sh
# 修复 / 清理电子书封面（不带日志）。
# 运行中提示与结束提示由 bin/msg.sh 统一给出。

. ./bin/config.sh

if [ ! -f "$PYTHON3" ]; then
    msg_fail "Python3 not found on Kindle"
    exit 0
fi

# 解析 KUAL 传入的所有参数
#   --clean         清理所有无效封面文件
#   --net           允许联网补齐封面
#   --missing-only  仅处理「没有封面」的电子书（配合 --net）
#   --speed         联网时先探测各源、把最快的排到最前
ACTION=""
NET_FLAG=""
SPEED_FLAG=""
MISSING_FLAG=""
for a in "$@"; do
    case "$a" in
        --clean)        ACTION="-a clean" ;;
        --net)          NET_FLAG="--net" ;;
        --speed)        SPEED_FLAG="--speed" ;;
        --missing-only) MISSING_FLAG="--missing-only" ;;
    esac
done

if [ "$ACTION" = "-a clean" ]; then
    msg_wait "Cleaning invalid cover files"
elif [ -n "$NET_FLAG" ]; then
    msg_wait "Fetching missing covers online (may take a while)"
else
    msg_wait "Fixing damaged ebook covers"
fi

$PYTHON3 $FIX_SCRIPT $KINDLE_PATH $ACTION $NET_FLAG $SPEED_FLAG $MISSING_FLAG
rc=$?

if [ "$rc" -ne 0 ]; then
    msg_fail "Cover tool error (rc=$rc)"
elif [ "$ACTION" = "-a clean" ]; then
    msg_ok "Invalid cover files cleared"
elif [ -n "$NET_FLAG" ]; then
    msg_ok "Online cover fix finished (missing covers only)"
else
    msg_ok "Ebook covers fixed"
fi
