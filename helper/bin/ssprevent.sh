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

# 禁用屏保：恢复原始 helper 方案，直接通过 lipc 关闭 powerd 屏保。
# 不再写状态文件：该属性重启后会复位，两个菜单常驻、随时可重新点击。
# 屏幕反馈与运行日志已由 common.sh 统一加载（见 bin/common.sh）。
:

LIPC=''
if command -v lipc-set-prop >/dev/null 2>&1; then
    LIPC=lipc-set-prop
elif [ -x /usr/bin/lipc-set-prop ]; then
    LIPC=/usr/bin/lipc-set-prop
elif [ -x /usr/sbin/lipc-set-prop ]; then
    LIPC=/usr/sbin/lipc-set-prop
fi

msg_wait "Disabling screen saver"

if [ -z "$LIPC" ]; then
    msg_fail "lipc-set-prop not found"
    exit 0
fi

"$LIPC" -i com.lab126.powerd preventScreenSaver 1
rc=$?
if [ "$rc" -eq 0 ]; then
    msg_ok "Screen saver disabled"
else
    msg_fail "lipc-set-prop failed (rc=$rc)"
fi
