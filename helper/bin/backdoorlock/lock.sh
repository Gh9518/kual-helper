#!/bin/sh

# 由 $0 的真实路径定位插件根目录（向上查找 config.xml），不依赖调用方的工作目录；
# 找不到时回退到标准安装路径。KUAL_HOME 可由测试环境覆盖。
_kh=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || _kh=''
case "$_kh" in ''|/) _kh=/mnt/us/extensions/helper ;; esac
while [ "$_kh" != / ] && [ ! -f "$_kh/config.xml" ]; do _kh=$(dirname "$_kh"); done
[ -f "$_kh/config.xml" ] || _kh=/mnt/us/extensions/helper
KUAL_HOME=${KUAL_HOME:-$_kh}

# 锁定更新（backdoorlock 开启）：劫持 updater.conf、注释 OTA 处理器。不带日志。
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

msg_wait "Enabling Back Door Lock"

/usr/sbin/mntroot rw
sed -i 's|^_UPDATE_WAIT=.*$|_UPDATE_WAIT="$(if [ -x /mnt/us/extensions/helper/backdoorlock/updatewait ]; then echo /mnt/us/extensions/helper/backdoorlock/updatewait; else echo /usr/sbin/updatewait; fi)"|' /etc/updater.conf
if [ -f /etc/todo/handler_registry.conf ]
then
    sed -i 's/^[^#].*=com[.]lab126[.]ota.*$/#\0/g' /etc/todo/handler_registry.conf
fi
/usr/sbin/mntroot ro
[ -f /etc/todo/handler_registry.conf ] && /sbin/restart todo

msg_ok "Back Door Lock enabled"
