#!/bin/sh

# 由 $0 的真实路径定位插件根目录（向上查找 config.xml），不依赖调用方的工作目录；
# 找不到时回退到标准安装路径。KUAL_HOME 可由测试环境覆盖。
_kh=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || _kh=''
case "$_kh" in ''|/) _kh=/mnt/us/extensions/helper ;; esac
while [ "$_kh" != / ] && [ ! -f "$_kh/config.xml" ]; do _kh=$(dirname "$_kh"); done
[ -f "$_kh/config.xml" ] || _kh=/mnt/us/extensions/helper
KUAL_HOME=${KUAL_HOME:-$_kh}

# 屏蔽更新（BlockKindleOTA 开启）：重命名 OTA 二进制并写入占位脚本。
# 幂等保护：已屏蔽时直接退出，避免重复点击把占位脚本再次备份、
# 覆盖真正的 .bck 备份导致以后无法恢复。
if [ -r "$KUAL_HOME/bin/msg.sh" ]; then
    . "$KUAL_HOME/bin/msg.sh"
else
    _log_write() { return 0; }
    [ -n "$KUAL_HOME" ] && [ -r "$KUAL_HOME/bin/log.sh" ] && . "$KUAL_HOME/bin/log.sh"
    _eips=$(command -v eips 2>/dev/null)
    msg_show() { [ -n "$_eips" ] && "$_eips" 2 "$1" "$2" >/dev/null 2>&1; printf '[KUAL] %s\n' "$2" >&2; }
    msg_wait() { msg_show 3 "Waiting... $*"; _log_write START "$*"; }
    msg_info() { msg_show 3 "$*"; _log_write INFO "$*"; }
    msg_ok()   { msg_show 4 "Done: $*"; _log_write OK "$*"; }
    msg_fail() { msg_show 4 "Failed: $*"; _log_write FAIL "$*"; }
fi

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
