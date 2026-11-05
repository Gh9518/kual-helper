#!/bin/sh
# 删除更新：删除系统已有的 OTA 更新文件（sideload 的 update*.bin 与下载中的固件包）。
# 不带日志，只在屏幕给出运行中提示与结果。
. ./bin/msg.sh

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
