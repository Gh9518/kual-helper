#!/bin/sh

# 公共引导：由 $0 向上定位并加载 common.sh（KUAL_HOME 定位 / 屏幕反馈 / 运行日志）。
# 找不到 common.sh 时仅降级屏幕反馈，主动作不受影响。
_b=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || _b=''
while [ -n "$_b" ] && [ "$_b" != / ] && [ ! -f "$_b/common.sh" ]; do _b=$(dirname "$_b"); done
if [ -f "$_b/common.sh" ]; then
    . "$_b/common.sh"
else
    msg_wait(){ :; }; msg_info(){ :; }; msg_ok(){ :; }
    msg_fail(){ printf '[KUAL] FAILED: %s\n' "$*" >&2; }
fi
unset _b

# 检查 / 更新插件：从 GitHub Release 拉取最新版本。
# 仓库与资产名在 bin/config.sh 中配置（GITHUB_REPO / GITHUB_ASSET）。
#   --check : 只报告版本差异，不执行更新。

if [ -r "$KUAL_HOME/bin/config.sh" ]; then
    . "$KUAL_HOME/bin/config.sh"
else
    KINDLE_PATH=/mnt/us
    PYTHON3=$(command -v python3 2>/dev/null)
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
