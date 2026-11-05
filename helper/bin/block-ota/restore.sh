#!/bin/sh

# 由 $0 的真实路径定位插件根目录（向上查找 config.xml），不依赖调用方的工作目录；
# 找不到时回退到标准安装路径。KUAL_HOME 可由测试环境覆盖。
_kh=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || _kh=''
case "$_kh" in ''|/) _kh=/mnt/us/extensions/helper ;; esac
while [ "$_kh" != / ] && [ ! -f "$_kh/config.xml" ]; do _kh=$(dirname "$_kh"); done
[ -f "$_kh/config.xml" ] || _kh=/mnt/us/extensions/helper
KUAL_HOME=${KUAL_HOME:-$_kh}

# 恢复更新（BlockKindleOTA 关闭并恢复）：还原 OTA 二进制备份。
# 幂等保护：没有 .bck 备份（即未屏蔽）时不做任何改动、不重启，
# 避免 mv 报错后仍把 otaupd/otav3 弄丢。
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
