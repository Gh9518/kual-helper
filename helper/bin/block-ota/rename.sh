#!/bin/sh
# 屏蔽更新（BlockKindleOTA 开启）：重命名 OTA 二进制并写入占位脚本。
# 幂等保护：已屏蔽时直接退出，避免重复点击把占位脚本再次备份、
# 覆盖真正的 .bck 备份导致以后无法恢复。
. ./bin/msg.sh

msg_wait "Blocking OTA updates"

mntroot rw
rm -f /mnt/us/update*.bin 2>/dev/null
cd /usr/bin || { mntroot ro; msg_fail "Cannot access /usr/bin"; exit 0; }

if [ -f otaupd.bck ] || [ -f otav3.bck ]; then
    mntroot ro
    msg_ok "OTA already blocked, nothing to do"
    exit 0
fi

mv otaupd otaupd.bck
mv otav3 otav3.bck

printf '#!/bin/sh\n/bin/true\n' > /usr/bin/otav3
printf '#!/bin/sh\n/bin/true\n' > /usr/bin/otaupd
chmod 755 /usr/bin/otav3 /usr/bin/otaupd

mntroot ro
msg_ok "OTA binaries replaced, rebooting..."
sleep 2
reboot
