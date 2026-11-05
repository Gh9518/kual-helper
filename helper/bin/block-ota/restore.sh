#!/bin/sh
# 恢复更新（BlockKindleOTA 关闭并恢复）：还原 OTA 二进制备份。
# 幂等保护：没有 .bck 备份（即未屏蔽）时不做任何改动、不重启，
# 避免 mv 报错后仍把 otaupd/otav3 弄丢。
. ./bin/msg.sh

msg_wait "Restoring OTA updates"

mntroot rw
cd /usr/bin || { mntroot ro; msg_fail "Cannot access /usr/bin"; exit 0; }

if [ ! -f otaupd.bck ] || [ ! -f otav3.bck ]; then
    mntroot ro
    msg_ok "OTA not blocked, nothing to restore"
    exit 0
fi

rm -f otaupd otav3
mv otaupd.bck otaupd
mv otav3.bck otav3

mntroot ro
msg_ok "OTA binaries restored, rebooting..."
sleep 2
reboot
