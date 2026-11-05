#!/bin/sh

#------------------------
# bookfere.com (extended)
#------------------------

. ./bin/config.sh

print_err() {
    print_log 4 'Unexpected error occurs.'
}

if [ ! -f "$PYTHON3" ]; then
    print_log 3 'Need to install Python3 (>=3.5) on the Kindle.'
    exit 0
fi

print_log 3 'Working...'

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

$PYTHON3 $FIX_SCRIPT $KINDLE_PATH $ACTION $NET_FLAG $SPEED_FLAG $MISSING_FLAG
if [ $? = 0 ]; then
    if [ "$ACTION" = "-a clean" ]; then
        print_log 4 'All invalid ebook covers were deleted.'
    elif [ -n "$NET_FLAG" ]; then
        print_log 4 'Online cover fix done (missing-cover ebooks only).'
    else
        print_log 4 'All damaged ebook covers were fixed.'
    fi
else
    print_err
fi
