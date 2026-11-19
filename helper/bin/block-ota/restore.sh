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

# 恢复更新（BlockKindleOTA 关闭并恢复）：还原 OTA 二进制备份。
# 幂等保护：没有 .bck 备份（即未屏蔽）时不做任何改动、不重启，
# 避免 mv 报错后仍把 otaupd/otav3 弄丢。
# 屏幕反馈与运行日志已由 common.sh 统一加载（见 bin/common.sh）。
:

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
