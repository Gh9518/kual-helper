#!/bin/sh

# 由 $0 的真实路径定位插件根目录（向上查找 config.xml），不依赖调用方的工作目录；
# 找不到时回退到标准安装路径。KUAL_HOME 可由测试环境覆盖。
_kh=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || _kh=''
case "$_kh" in ''|/) _kh=/mnt/us/extensions/helper ;; esac
while [ "$_kh" != / ] && [ ! -f "$_kh/config.xml" ]; do _kh=$(dirname "$_kh"); done
[ -f "$_kh/config.xml" ] || _kh=/mnt/us/extensions/helper
KUAL_HOME=${KUAL_HOME:-$_kh}


#------------------------
# bookfere.com
#------------------------

KINDLE_PATH=/mnt/us

SDR_SCRIPT="$KUAL_HOME/bin/sdr-cleaner/sdr_cleaner.py"
FIX_SCRIPT="$KUAL_HOME/bin/fix-cover/fix_cover.py"

# 统一屏幕反馈（Waiting / Done / Failed），见 bin/msg.sh
if [ -r "$KUAL_HOME/bin/msg.sh" ]; then
    . "$KUAL_HOME/bin/msg.sh"
else
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

get_python() {
    for PYTHON_PATH in $1; do
        if [ -f $PYTHON_PATH ]; then
            echo $PYTHON_PATH
            break
        fi
    done
}

PYTHON2=$(get_python '/usr/bin/python /mnt/us/python2/bin/python2.7')
PYTHON3=$(get_python '/usr/bin/python3 /mnt/us/python3/bin/python3.8 /mnt/us/python3/bin/python3.9')

#--------------------------------------------------------------
# 插件更新（GitHub）
# 通过 GitHub Release 检测并更新本插件。
#   GITHUB_REPO : 发布仓库，格式 "所有者/仓库名"
#   GITHUB_ASSET: Release 中的更新包文件名（zip，顶层含 helper/ 目录）
#   EXT_PATH    : 本插件在 Kindle 上的安装路径
# 已指向正式发布仓库；如 fork 到你自己的账号，改这一行即可。
#--------------------------------------------------------------
GITHUB_REPO="Gh9518/kual-helper"
GITHUB_ASSET="helper.zip"
EXT_PATH=/mnt/us/extensions/helper
