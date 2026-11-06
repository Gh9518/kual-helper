#!/bin/sh
# KUAL 屏幕反馈公共模块。
# 真机：用 Kindle 的 eips 在屏幕第 3 行（进行中）/ 第 4 行（结果）显示文字。
# eips 使用固化的 ASCII 字体，中文会显示为方块，因此屏幕提示统一用简短英文；
# 菜单与 KUAL 状态栏由 KUAL 自身渲染，可以正常显示中文。
# 离线测试（无 eips）：提示输出到 stderr；设置 KUAL_MSG_LOG 可同时落盘便于校验。
#
# 运行日志：所有屏幕反馈同时写入 $KUAL_HOME/logs/（见 bin/log.sh，含 3 天保留策略）。
# 日志不可写时静默降级，不影响屏幕提示与主动作。

KUAL_EIPS=''
for _p in /usr/sbin/eips /usr/bin/eips /sbin/eips /bin/eips; do
    [ -x "$_p" ] && KUAL_EIPS="$_p" && break
done
[ -n "$KUAL_EIPS" ] || KUAL_EIPS=$(command -v eips 2>/dev/null)
[ -n "$KUAL_EIPS" ] || KUAL_EIPS=eips

# 加载运行日志模块；缺失时提供空实现，保证下面的函数始终可调用。
if [ -n "$KUAL_HOME" ] && [ -r "$KUAL_HOME/bin/log.sh" ]; then
    . "$KUAL_HOME/bin/log.sh"
else
    _log_write() { return 0; }
fi

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

msg_wait() { msg_show 3 "Waiting... $*"; _log_write START "$*"; }
msg_info() { msg_show 3 "$*"; _log_write INFO "$*"; }
msg_ok()   { msg_show 4 "Done: $*"; _log_write OK "$*"; }
msg_fail() { msg_show 4 "Failed: $*"; _log_write FAIL "$*"; }

# 保证 source 返回 0（探测不到 eips 时也不影响调用脚本继续执行）
:
