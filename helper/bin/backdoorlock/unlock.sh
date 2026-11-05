#!/bin/sh
# 解锁更新（backdoorlock 关闭并恢复）：还原 updater.conf 与 OTA 处理器。不带日志。

/usr/sbin/mntroot rw
sed -i 's|^_UPDATE_WAIT=.*$|_UPDATE_WAIT="/usr/sbin/updatewait"|' /etc/updater.conf
if [ -f /etc/todo/handler_registry.conf ]
then
    sed -i 's/^[#]\(.*=com[.]lab126[.]ota.*\)$/\1/g' /etc/todo/handler_registry.conf
fi
/usr/sbin/mntroot ro
[ -f /etc/todo/handler_registry.conf ] && /sbin/restart todo
