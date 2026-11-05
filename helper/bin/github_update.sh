#!/bin/sh

# Update helper from its GitHub release.
# The repo / asset are configured in bin/config.sh (GITHUB_REPO, GITHUB_ASSET).
#   --check : only report version difference, do not apply.

. ./bin/config.sh

print_err() {
    print_log 4 'Unexpected error occurs.'
}

# 未配置 / 仍是占位仓库时给出提示（兼容任意占位写法）。
case "$GITHUB_REPO" in
    ''|owner/*|yourname/*|*OWNER*|*example*) 
        print_log 3 '请先在 bin/config.sh 中设置 GITHUB_REPO'
        exit 0 ;;
esac

if [ ! -f "$PYTHON3" ]; then
    print_log 3 '需要 Kindle 上安装 Python3 (>=3.5)。'
    exit 0
fi

MSG=$($PYTHON3 ./bin/github_update.py "$GITHUB_REPO" "$GITHUB_ASSET" "$EXT_PATH" "$1" 2>&1)
print_log 3 "$MSG"
