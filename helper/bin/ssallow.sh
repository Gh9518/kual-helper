#!/bin/sh
# 允许屏保（恢复系统屏保 / 睡眠），并删除状态标记供 KUAL 菜单互斥显示。
# 状态文件不存在 == 当前允许屏保，菜单将改显「禁用屏保」。
STATE=${SS_STATE:-/mnt/us/extensions/helper/.screensaver_disabled}
lipc-set-prop -i com.lab126.powerd preventScreenSaver 0
rm -f "$STATE" 2>/dev/null
