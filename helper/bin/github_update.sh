#!/bin/sh

# 由 $0 的真实路径定位插件根目录（向上查找 config.xml），不依赖调用方的工作目录；
# 找不到时回退到标准安装路径。KUAL_HOME 可由测试环境覆盖。
_kh=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || _kh=''
case "$_kh" in ''|/) _kh=/mnt/us/extensions/helper ;; esac
while [ "$_kh" != / ] && [ ! -f "$_kh/config.xml" ]; do _kh=$(dirname "$_kh"); done
[ -f "$_kh/config.xml" ] || _kh=/mnt/us/extensions/helper
KUAL_HOME=${KUAL_HOME:-$_kh}

# 检查 / 更新插件：从 GitHub Release 拉取最新版本。
# 仓库与资产名在 bin/config.sh 中配置（GITHUB_REPO / GITHUB_ASSET）。
#   --check : 只报告版本差异，不执行更新。

if [ -r "$KUAL_HOME/bin/config.sh" ]; then
    . "$KUAL_HOME/bin/config.sh"
else
    KINDLE_PATH=/mnt/us
    PYTHON3=$(command -v python3 2>/dev/null)
    if [ -r "$KUAL_HOME/bin/msg.sh" ]; then
        . "$KUAL_HOME/bin/msg.sh"
    else
        _eips=$(command -v eips 2>/dev/null)
        msg_show() { [ -n "$_eips" ] && "$_eips" 2 "$1" "$2" >/dev/null 2>&1; printf '[KUAL] %s\n' "$2" >&2; }
        msg_wait() { msg_show 3 "Waiting... $*"; }
        msg_info() { msg_show 3 "$*"; }
        msg_ok()   { msg_show 4 "Done: $*"; }
        msg_fail() { msg_show 4 "Failed: $*"; }
    fi
fi

# 未配置 / 仍是占位仓库时给出提示（兼容任意占位写法）。
case "$GITHUB_REPO" in
    ''|owner/*|yourname/*|*OWNER*|*example*)
        msg_fail "GITHUB_REPO not set in bin/config.sh"
        exit 0 ;;
esac

if [ ! -f "$PYTHON3" ]; then
    msg_fail "Python3 not found on Kindle"
    exit 0
fi

msg_wait "Checking GitHub for updates"

TMP=/tmp/kual_upd_msg_$$
$PYTHON3 "$KUAL_HOME/bin/github_update.py" "$GITHUB_REPO" "$GITHUB_ASSET" "$EXT_PATH" "$1" > "$TMP" 2>&1
rc=$?
while IFS= read -r line; do
    [ -n "$line" ] || continue
    msg_info "$line"
done < "$TMP"
rm -f "$TMP"

if [ "$rc" -eq 0 ]; then
    msg_ok "Update check finished"
else
    msg_fail "Update check failed (rc=$rc)"
fi
