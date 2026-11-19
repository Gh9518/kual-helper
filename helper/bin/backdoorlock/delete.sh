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

# 删除更新：删除系统已有的 OTA 更新文件（sideload 的 update*.bin 与下载中的固件包）。
# 不带日志，只在屏幕给出运行中提示与结果。
# 屏幕反馈与运行日志已由 common.sh 统一加载（见 bin/common.sh）。
:

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
