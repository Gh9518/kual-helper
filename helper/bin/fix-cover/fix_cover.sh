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

# 修复 / 清理电子书封面（不带日志）。
# 运行中提示与结束提示由 bin/msg.sh 统一给出。

if [ -r "$KUAL_HOME/bin/config.sh" ]; then
    . "$KUAL_HOME/bin/config.sh"
else
    KINDLE_PATH=/mnt/us
    PYTHON3=$(command -v python3 2>/dev/null)
fi

if [ ! -f "$PYTHON3" ]; then
    msg_fail "Python3 not found on Kindle"
    exit 0
fi

# 运行时防锁屏：封面修复 / 联网补封面在真机上可能持续数分钟，
# 期间禁止 Kindle 休眠，避免脚本被冻结、WiFi 掉线。结束时自动恢复原状态。
if [ -r "$KUAL_HOME/bin/nolock.sh" ]; then
    . "$KUAL_HOME/bin/nolock.sh"
else
    nolock_begin() { return 0; }
    nolock_end()   { return 0; }
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

nolock_begin
trap 'nolock_end' EXIT
trap 'exit 130' INT TERM HUP

# Progress goes to a temp file: on success it is discarded silently, but if
# the tool is killed (rc=137 = SIGKILL, i.e. the Kindle OOM killer) the last
# processed book is written to the run log so the culprit can be identified.
COV_OUT=/tmp/kual_cover_progress_$$
$PYTHON3 $FIX_SCRIPT $KINDLE_PATH $ACTION $NET_FLAG $SPEED_FLAG $MISSING_FLAG \
    > "$COV_OUT" 2>&1
rc=$?

if [ "$rc" -ne 0 ]; then
    _last=$(grep -v '^---' "$COV_OUT" 2>/dev/null | tail -n 2 | tr '\n' ' ')
    [ -n "$_last" ] && msg_info "Last processed: $_last"
    if [ "$rc" -eq 137 ]; then
        msg_fail "Killed: low memory (rc=137), run Clean Invalid Covers first"
    else
        msg_fail "Cover tool error (rc=$rc)"
    fi
elif [ "$ACTION" = "-a clean" ]; then
    msg_ok "Invalid cover files cleared"
elif [ -n "$NET_FLAG" ]; then
    msg_ok "Online cover fix finished (missing covers only)"
else
    msg_ok "Ebook covers fixed"
fi
rm -f "$COV_OUT"

nolock_end
