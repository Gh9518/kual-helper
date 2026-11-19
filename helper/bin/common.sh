#!/bin/sh
# KUAL Helper 公共引导模块（由 bin/ 下所有动作脚本 source）。
#
# 职责（唯一实现处，避免 14 个脚本各自复制导致行为漂移）：
#   ① 由 $0 的真实路径向上查找 config.xml 定位插件根目录 KUAL_HOME，
#      不依赖调用方工作目录；KUAL_HOME 可由测试环境预先覆盖。
#   ② 加载统一屏幕反馈 msg.sh（其内部会加载运行日志 log.sh）。
#   ③ msg.sh / log.sh 缺失时提供等价降级，保证任一动作不因单个文件缺失而失效。
#   ④ 提供 print_log 兼容函数。
#
# 约束：任何一步失败都静默降级，绝不改变主动作的返回码或屏幕反馈。

# 幂等：被重复 source（如脚本先 source common.sh 又 source config.sh）时直接返回，
# 避免 msg.sh/log.sh 二次加载导致日志重复初始化。return 仅在被 source 时有效，
# 直接执行时 shell 会忽略该失败并继续（后面统一用 `|| :` 兜底）。
if [ -n "$KUAL_COMMON_LOADED" ]; then
    return 0 2>/dev/null || :
fi
KUAL_COMMON_LOADED=1

if [ -z "$KUAL_HOME" ]; then
    _kh=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || _kh=''
    case "$_kh" in ''|/) _kh=/mnt/us/extensions/helper ;; esac
    while [ "$_kh" != / ] && [ ! -f "$_kh/config.xml" ]; do _kh=$(dirname "$_kh"); done
    [ -f "$_kh/config.xml" ] || _kh=/mnt/us/extensions/helper
    KUAL_HOME=$_kh
    unset _kh
fi

if [ -r "$KUAL_HOME/bin/msg.sh" ]; then
    . "$KUAL_HOME/bin/msg.sh"
else
    # msg.sh 缺失时的最小降级：仍保证所有 msg_* 可调用且写运行日志。
    _log_write() { return 0; }
    [ -n "$KUAL_HOME" ] && [ -r "$KUAL_HOME/bin/log.sh" ] && . "$KUAL_HOME/bin/log.sh"
    _eips=$(command -v eips 2>/dev/null)
    msg_show() { [ -n "$_eips" ] && "$_eips" 2 "$1" "$2" >/dev/null 2>&1; printf '[KUAL] %s\n' "$2" >&2; }
    msg_wait() { msg_show 3 "Waiting... $*"; _log_write START "$*"; }
    msg_info() { msg_show 3 "$*"; _log_write INFO "$*"; }
    msg_ok()   { msg_show 4 "Done: $*"; _log_write OK "$*"; }
    msg_fail() { msg_show 4 "Failed: $*"; _log_write FAIL "$*"; }
fi

# 兼容旧写法：print_log <行号> <文本>
print_log() {
    _row=$1
    shift
    msg_show "$_row" "$*"
}

# 保证被 source 时返回 0
:
