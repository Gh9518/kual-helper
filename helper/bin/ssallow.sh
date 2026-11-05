#!/bin/sh
# 允许屏保：恢复原始 helper 方案，直接通过 lipc 恢复 powerd 屏保。
. ./bin/msg.sh

LIPC=''
if command -v lipc-set-prop >/dev/null 2>&1; then
    LIPC=lipc-set-prop
elif [ -x /usr/bin/lipc-set-prop ]; then
    LIPC=/usr/bin/lipc-set-prop
elif [ -x /usr/sbin/lipc-set-prop ]; then
    LIPC=/usr/sbin/lipc-set-prop
fi

msg_wait "Enabling screen saver"

if [ -z "$LIPC" ]; then
    msg_fail "lipc-set-prop not found"
    exit 0
fi

"$LIPC" -i com.lab126.powerd preventScreenSaver 0
rc=$?
if [ "$rc" -eq 0 ]; then
    msg_ok "Screen saver enabled"
else
    msg_fail "lipc-set-prop failed (rc=$rc)"
fi
