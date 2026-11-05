#!/bin/sh

#------------------------
# bookfere.com
#------------------------

KINDLE_PATH=/mnt/us

SDR_SCRIPT=./bin/sdr-cleaner/sdr_cleaner.py
FIX_SCRIPT=./bin/fix-cover/fix_cover.py

print_log() {
    eips 2 $1 "$2" &>/dev/null
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
