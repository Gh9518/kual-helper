#!/bin/sh

# 由 $0 的真实路径定位插件根目录（向上查找 config.xml），不依赖调用方的工作目录；
# 找不到时回退到标准安装路径。KUAL_HOME 可由测试环境覆盖。
_kh=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || _kh=''
case "$_kh" in ''|/) _kh=/mnt/us/extensions/helper ;; esac
while [ "$_kh" != / ] && [ ! -f "$_kh/config.xml" ]; do _kh=$(dirname "$_kh"); done
[ -f "$_kh/config.xml" ] || _kh=/mnt/us/extensions/helper
KUAL_HOME=${KUAL_HOME:-$_kh}

# 删除更新：删除系统已有的 OTA 更新文件（sideload 的 update*.bin 与下载中的固件包）。
# 不带日志，只在屏幕给出运行中提示与结果。
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

US_ROOT=${US_ROOT:-/mnt/us}

cd "$US_ROOT" 2>/dev/null || {
    msg_fail "Cannot access $US_ROOT"
    exit 0
}

msg_wait "Deleting downloaded update files"

cnt=0
for f in update*.bin Update*.bin FWUO*.partial; do
    [ -f "$f" ] || continue
    # 这个占位文件是用来阻止重启安装的，不是更新包，不要误删
    case "$f" in *this-file-prevents*) continue ;; esac
    rm -f "$f" && cnt=$((cnt + 1))
done

if [ "$cnt" -gt 0 ]; then
    msg_ok "$cnt update file(s) deleted"
else
    msg_ok "No update files found"
fi
