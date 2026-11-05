#!/bin/sh
# 锁定更新（backdoorlock 开启）：劫持 updater.conf、注释 OTA 处理器。不带日志。
. ./bin/msg.sh

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
