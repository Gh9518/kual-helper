#!/bin/sh
# KUAL Helper 运行时防锁屏模块（由「修复失效」下的长耗时动作加载）。
#
# 背景：真机运行日志里「修复封面」约 7 分钟、「联网修复封面」约 7.5 分钟、
#       「修复谷歌」约 1 分钟。Kindle 默认的屏保 / 自动休眠会冻结这些脚本，
#       并让 WiFi 掉线，导致联网动作中途失败。
#
# 机制：lipc-set-prop -i com.lab126.powerd preventScreenSaver 1 是 Kindle 官方的
#       「禁止休眠和自动锁屏」开关，附带保持 WiFi 在线的效果，重启后自动复位。
#       本模块先用 lipc-get-prop 读取动作前的状态：
#         · 原状态 0 → 临时设为 1，动作结束时恢复 0；
#         · 原状态 1（用户已点「禁用屏保」）→ 不改动、也不恢复，绝不覆盖用户设置。
#       nolock_end 幂等，配合调用脚本的 trap 可保证异常退出也能恢复。
#
# 用法：加载 msg.sh 之后调用 nolock_begin，并设置
#       trap 'nolock_end' EXIT INT TERM HUP
#
# 约束：lipc 命令缺失、读写失败一律静默跳过，不改变主动作与屏幕反馈的返回码。

NOLOCK_SET=''
NOLOCK_GET=''
for _nlp in /usr/bin/lipc-set-prop /usr/sbin/lipc-set-prop /bin/lipc-set-prop; do
    [ -x "$_nlp" ] && NOLOCK_SET=$_nlp && break
done
[ -n "$NOLOCK_SET" ] || NOLOCK_SET=$(command -v lipc-set-prop 2>/dev/null)
for _nlp in /usr/bin/lipc-get-prop /usr/sbin/lipc-get-prop /bin/lipc-get-prop; do
    [ -x "$_nlp" ] && NOLOCK_GET=$_nlp && break
done
[ -n "$NOLOCK_GET" ] || NOLOCK_GET=$(command -v lipc-get-prop 2>/dev/null)

NOLOCK_CHANGED=0
NOLOCK_ACTIVE=0

_nl_log() {
    command -v _log_write >/dev/null 2>&1 && _log_write INFO "$*"
    return 0
}

# 成功时回显 0/1，失败返回 1。依次尝试三种取法，兼容不同固件。
_nl_read_state() {
    [ -n "$NOLOCK_GET" ] || return 1
    _nlv=$("$NOLOCK_GET" -i com.lab126.powerd preventScreenSaver 2>/dev/null | tr -d '[:space:]')
    case "$_nlv" in 0|1) printf '%s' "$_nlv"; return 0 ;; esac
    _nlv=$("$NOLOCK_GET" com.lab126.powerd preventScreenSaver 2>/dev/null | tr -d '[:space:]')
    case "$_nlv" in 0|1) printf '%s' "$_nlv"; return 0 ;; esac
    # 部分固件只在 status 输出里暴露 prevent_screen_saver 字段；用 case 解析，
    # 不依赖 sed / awk，避免再引入外部命令。
    _nls=$("$NOLOCK_GET" com.lab126.powerd status 2>/dev/null)
    case "$_nls" in
        *prevent_screen_saver:1*) printf '1'; return 0 ;;
        *prevent_screen_saver:0*) printf '0'; return 0 ;;
    esac
    return 1
}

nolock_begin() {
    [ -n "$NOLOCK_SET" ] || return 0
    _nl_prev=$(_nl_read_state) || _nl_prev=0
    if [ "$_nl_prev" = 1 ]; then
        _nl_log "Screen saver already disabled by user (kept)"
        return 0
    fi
    "$NOLOCK_SET" -i com.lab126.powerd preventScreenSaver 1 >/dev/null 2>&1 || {
        _nl_log "Could not suppress screen saver (lipc failed)"
        return 0
    }
    NOLOCK_CHANGED=1
    NOLOCK_ACTIVE=1
    _nl_log "Screen saver suppressed during action"
    return 0
}

nolock_end() {
    [ "$NOLOCK_CHANGED" -eq 1 ] || return 0
    NOLOCK_CHANGED=0
    [ -n "$NOLOCK_SET" ] || return 0
    "$NOLOCK_SET" -i com.lab126.powerd preventScreenSaver 0 >/dev/null 2>&1
    NOLOCK_ACTIVE=0
    _nl_log "Screen saver restored after action"
    return 0
}

# 保证被 source 时返回 0
:
