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

# 屏蔽更新（BlockKindleOTA 开启）：重命名 OTA 二进制并写入占位脚本。
# 幂等保护：已屏蔽时直接退出，避免重复点击把占位脚本再次备份、
# 覆盖真正的 .bck 备份导致以后无法恢复。
# 屏幕反馈与运行日志已由 common.sh 统一加载（见 bin/common.sh）。
:

msg_wait "Blocking OTA updates"

mntroot rw
rm -f /mnt/us/update*.bin 2>/dev/null
cd /usr/bin || { mntroot ro; msg_fail "Cannot access /usr/bin"; exit 0; }

if [ -f otaupd.bck ] || [ -f otav3.bck ]; then
    mntroot ro
    msg_ok "OTA already blocked, nothing to do"
    exit 0
fi

if ! mv otaupd otaupd.bck || ! mv otav3 otav3.bck; then
    mntroot ro
    msg_fail "Cannot back up OTA binaries (unexpected filesystem state)"
    exit 0
fi

printf '#!/bin/sh\n/bin/true\n' > /usr/bin/otav3
printf '#!/bin/sh\n/bin/true\n' > /usr/bin/otaupd
chmod 755 /usr/bin/otav3 /usr/bin/otaupd

mntroot ro
msg_ok "OTA binaries replaced, rebooting..."
sleep 2
reboot
