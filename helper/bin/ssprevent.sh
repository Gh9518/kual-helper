#!/bin/sh
# 禁用屏保：恢复原始 helper 方案，直接通过 lipc 关闭 powerd 屏保。
# 不再写状态文件：该属性重启后会复位，两个菜单常驻、随时可重新点击。
. ./bin/msg.sh

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
