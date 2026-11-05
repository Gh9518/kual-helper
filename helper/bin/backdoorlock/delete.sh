#!/bin/sh
# 删除更新：删除系统已有的 OTA 更新文件（sideload 的 update*.bin 与下载中的固件包）。
# 不带日志，只在屏幕上给出结果。

US_ROOT=${US_ROOT:-/mnt/us}

eips_msg() {
    if [ -x /usr/sbin/eips ]; then
        /usr/sbin/eips 2 3 "$1" >/dev/null 2>&1
    else
        eips 2 3 "$1" >/dev/null 2>&1
    fi
}

cd "$US_ROOT" 2>/dev/null || {
    eips_msg "无法访问 $US_ROOT"
    exit 0
}

cnt=0
for f in update*.bin Update*.bin FWUO*.partial; do
    [ -f "$f" ] || continue
    # 这个占位文件是用来阻止重启安装的，不是更新包，不要误删
    case "$f" in *this-file-prevents*) continue ;; esac
    rm -f "$f" && cnt=$((cnt + 1))
done

if [ "$cnt" -gt 0 ]; then
    eips_msg "已删除 $cnt 个更新文件"
else
    eips_msg "没有发现更新文件"
fi
