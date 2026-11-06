#!/bin/sh
# KUAL Helper 运行日志模块（由 bin/msg.sh 加载）。
#
# 目的：每个菜单动作的「开始 / 进行中 / 成功 / 失败」都留痕，便于事后确认是否成功。
# 位置：$KUAL_HOME/logs/（USB 可见区，随插件一起安装 / 卸载）。
# 文件：按天一个 run-YYYYMMDD.log，UTF-8 追加写；每行
#       [YYYY-MM-DD HH:MM:SS] LEVEL 动作标识 | 结果文本
# 级别：START 开始 / INFO 过程 / OK 成功 / FAIL 失败
#
# 保留策略：每次动作启动（本模块被加载时）执行一次
#   ① 按文件修改时间删除「3 天前及更早」的日志（find -mtime +2）
#   ② 最多保留 KUAL_LOG_MAX_FILES 个文件（默认 10），防设备时钟异常导致堆积
#   ③ 当天日志超过 KUAL_LOG_MAX_BYTES（默认 256KB）时轮转为 .1.log 再新建
# 说明：按天分文件 + ① 让「超过 3 天」的管理变得直观；②③ 是额外的兜底上限，
#       避免设备时钟回拨或某次动作异常刷屏把 U 盘写满。
#
# 约束：任何一步失败都静默忽略，绝不改变主动作的返回码或屏幕反馈。

KUAL_LOG_DIR=${KUAL_LOG_DIR:-$KUAL_HOME/logs}
KUAL_LOG_KEEP_DAYS=${KUAL_LOG_KEEP_DAYS:-3}
KUAL_LOG_MAX_FILES=${KUAL_LOG_MAX_FILES:-10}
KUAL_LOG_MAX_BYTES=${KUAL_LOG_MAX_BYTES:-262144}

# 动作标识：脚本名 + 原始参数。在模块加载时快照，避免脚本内部 set -- 改写位置参数。
_log_args=$*
KUAL_ACTION=${KUAL_ACTION:-"$(basename "$0" 2>/dev/null)${_log_args:+ $_log_args}"}
unset _log_args

_log_ready=0
_log_file=''

_log_rotate() {
    [ -d "$KUAL_LOG_DIR" ] || return 0
    # ① 按修改时间清理。KEEP_DAYS=3 -> find -mtime +2（文件年龄 >= 3 天）
    _older=$((KUAL_LOG_KEEP_DAYS - 1))
    [ "$_older" -ge 0 ] || _older=0
    find "$KUAL_LOG_DIR" -type f -name 'run-*.log*' -mtime +"$_older" \
        -exec rm -f {} \; 2>/dev/null
    # ② 数量上限：按文件名（日期）升序，删掉最旧的
    _cnt=$(ls -1 "$KUAL_LOG_DIR"/run-*.log* 2>/dev/null | wc -l)
    case "$_cnt" in ''|*[!0-9]*) _cnt=0 ;; esac
    if [ "$_cnt" -gt "$KUAL_LOG_MAX_FILES" ]; then
        _drop=$((_cnt - KUAL_LOG_MAX_FILES))
        ls -1 "$KUAL_LOG_DIR"/run-*.log* 2>/dev/null | sort | head -n "$_drop" |
            while IFS= read -r _old; do rm -f "$_old" 2>/dev/null; done
    fi
    return 0
}

_log_init() {
    mkdir -p "$KUAL_LOG_DIR" 2>/dev/null || return 0
    [ -w "$KUAL_LOG_DIR" ] || return 0
    _day=$(date +%Y%m%d 2>/dev/null)
    [ -n "$_day" ] || _day=unknown
    _log_file="$KUAL_LOG_DIR/run-$_day.log"
    _log_rotate
    # ③ 单文件大小上限：超限先轮转，再新建当天文件
    if [ -f "$_log_file" ]; then
        _sz=$(wc -c < "$_log_file" 2>/dev/null) || _sz=0
        case "$_sz" in ''|*[!0-9]*) _sz=0 ;; esac
        if [ "$_sz" -gt "$KUAL_LOG_MAX_BYTES" ]; then
            mv -f "$_log_file" "$_log_file.1" 2>/dev/null
        fi
    fi
    : >> "$_log_file" 2>/dev/null || return 0
    _log_ready=1
    return 0
}

_log_write() {
    [ "$_log_ready" -eq 1 ] || return 0
    _lvl=$1
    shift
    _ts=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null) || _ts='-'
    printf '[%s] %-5s %s | %s\n' "$_ts" "$_lvl" "$KUAL_ACTION" "$*" >> "$_log_file" 2>/dev/null
    return 0
}

_log_init

# 保证被 source 时返回 0（日志不可写也不影响主动作）
:
