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

# 解锁更新（backdoorlock 关闭并恢复）：还原 updater.conf 与 OTA 处理器。不带日志。
# 屏幕反馈与运行日志已由 common.sh 统一加载（见 bin/common.sh）。
:

msg_wait "Disabling Back Door Lock"

/usr/sbin/mntroot rw
sed -i 's|^_UPDATE_WAIT=.*$|_UPDATE_WAIT="/usr/sbin/updatewait"|' /etc/updater.conf
if [ -f /etc/todo/handler_registry.conf ]
then
    sed -i 's/^[#]\(.*=com[.]lab126[.]ota.*\)$/\1/g' /etc/todo/handler_registry.conf
fi
/usr/sbin/mntroot ro
[ -f /etc/todo/handler_registry.conf ] && /sbin/restart todo

msg_ok "Back Door Lock disabled"
