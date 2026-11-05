#!/bin/sh
# 禁用屏保（阻止系统进入屏保 / 睡眠），并写入状态标记供 KUAL 菜单互斥显示。
# 状态文件存在 == 当前已禁用屏保，菜单将改显「允许屏保」。
STATE=${SS_STATE:-/mnt/us/extensions/helper/.screensaver_disabled}
lipc-set-prop -i com.lab126.powerd preventScreenSaver 1
mkdir -p "$(dirname "$STATE")" 2>/dev/null
: > "$STATE" 2>/dev/null
