#!/bin/sh

# 由 $0 的真实路径定位插件根目录（向上查找 config.xml），不依赖调用方的工作目录；
# 找不到时回退到标准安装路径。KUAL_HOME 可由测试环境覆盖。
_kh=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || _kh=''
case "$_kh" in ''|/) _kh=/mnt/us/extensions/helper ;; esac
while [ "$_kh" != / ] && [ ! -f "$_kh/config.xml" ]; do _kh=$(dirname "$_kh"); done
[ -f "$_kh/config.xml" ] || _kh=/mnt/us/extensions/helper
KUAL_HOME=${KUAL_HOME:-$_kh}

# 禁用屏保：恢复原始 helper 方案，直接通过 lipc 关闭 powerd 屏保。
# 不再写状态文件：该属性重启后会复位，两个菜单常驻、随时可重新点击。
if [ -r "$KUAL_HOME/bin/msg.sh" ]; then
    . "$KUAL_HOME/bin/msg.sh"
else
    _eips=$(command -v eips 2>/dev/null)
    msg_show() { [ -n "$_eips" ] && "$_eips" 2 "$1" "$2" >/dev/null 2>&1; printf '[KUAL] %s\n' "$2" >&2; }
    msg_wait() { msg_show 3 "Waiting... $*"; }
    msg_info() { msg_show 3 "$*"; }
    msg_ok()   { msg_show 4 "Done: $*"; }
    msg_fail() { msg_show 4 "Failed: $*"; }
fi

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
