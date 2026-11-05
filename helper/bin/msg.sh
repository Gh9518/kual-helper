#!/bin/sh
# KUAL 屏幕反馈公共模块。
# 真机：用 Kindle 的 eips 在屏幕第 3 行（进行中）/ 第 4 行（结果）显示文字。
# eips 使用固化的 ASCII 字体，中文会显示为方块，因此屏幕提示统一用简短英文；
# 菜单与 KUAL 状态栏由 KUAL 自身渲染，可以正常显示中文。
# 离线测试（无 eips）：提示输出到 stderr；设置 KUAL_MSG_LOG 可同时落盘便于校验。

KUAL_EIPS=''
for _p in /usr/sbin/eips /usr/bin/eips /sbin/eips /bin/eips; do
    [ -x "$_p" ] && KUAL_EIPS="$_p" && break
done
[ -n "$KUAL_EIPS" ] || KUAL_EIPS=$(command -v eips 2>/dev/null)

msg_show() {
    _krow=$1
    shift
    _ktext="$*"
    if [ -n "$KUAL_EIPS" ] && [ -x "$KUAL_EIPS" ]; then
        "$KUAL_EIPS" 2 "$_krow" "$_ktext" >/dev/null 2>&1
    else
        printf '[KUAL] %s\n' "$_ktext" >&2
    fi
    if [ -n "$KUAL_MSG_LOG" ]; then
        printf 'row=%s %s\n' "$_krow" "$_ktext" >> "$KUAL_MSG_LOG"
    fi
    return 0
}

msg_wait() { msg_show 3 "Waiting... $*"; }
msg_info() { msg_show 3 "$*"; }
msg_ok()   { msg_show 4 "Done: $*"; }
msg_fail() { msg_show 4 "Failed: $*"; }
