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

# do.sh - KUAL add-ons processor by stepk, version 20130507,a
# $Id: do.sh 13380 2016-07-19 01:01:28Z NiLuJe $
# 改动：替换 / 恢复商店按钮时通过 bin/msg.sh 给出运行中提示与结果反馈；
#       失败分支补上 mntroot ro，避免系统分区停留在可写状态。

# kindle AWK is busybox AWK not gawk
[ -f /bin/awk ] || alias awk='/bin/busybox awk'

# 屏幕反馈与运行日志已由 common.sh 统一加载（见 bin/common.sh）。
:

CONFIGPATH="/mnt/us/extensions/KUAL.cfg"

# helpers
config_full_path () { #{{{
	a1="${1}"
	if [ -r "${CONFIGPATH}" ] ; then
		echo -n "${CONFIGPATH}"
	elif [ create = "${a1}" ] ; then
		echo "# ${CONFIGFILE##*/} - created on $(date)" > "${CONFIGPATH}" && echo -n "${CONFIGPATH}"
	fi
}
#}}}
get_option () { #{{{ option
	x=''
	eval "${1}="
	if [ -r "${CONFIGPATH}" ] ; then
		. "${CONFIGPATH}"
		x="${1}=\"\${KUAL_${1}}\""
		eval ${x}
	fi
}
#}}}
set_option () { #{{{ option value
	option="${1}" value="${2}" config="$(config_full_path create)" newtext=''
	newtext=$(awk 'BEGIN{nf=1} /^\s*KUAL_'${option}'=/{sub(/="?[^"]*"?/,"=\"'${value}'\"");nf=0} {print} END{exit nf}' "${config}" ||
		echo "KUAL_${option}=\"${value}\"")
	[ 0 -ne ${#newtext} ] && echo "${newtext}" > "${config}"
}
#}}}
KUAL_filepath () { #{{{
	# Look for the Booklet, first (NOTE: A better check would be to query appreg.db)
	if [ -f "/mnt/us/documents/KUAL.kual" ] ; then
		echo -n "com.mobileread.ixtab.kindlelauncher"
		return
	fi

	# Barring that, the Kindlet
	set +f
	set -- $(find /mnt/us/documents -name 'KUAL-KDK-*.azw2' -type f -print)
	[ -e "${1}" ] && echo -n "${1}"
}
#}}}
store_button_filepath () { #{{{
	KT532="/usr/share/webkit-1.0/pillow/javascripts/search_bar.js"
	[ -e "${KT532}" ] && echo -n "${KT532}"
}
#}}}
screen_msg () { #{{{
	msg_show 3 "${*}"
}
#}}}

# add-ons start here
purge_KUAL_cache () { #{{{
	rm -f "/var/tmp/KUAL.cache"
}
#}}}
toggle_collation () { #{{{
	get_option collate
	case "${collate}" in
		"true" )
			set_option "collate" "false"
		;;
		"false" | '' )
			set_option "collate" "true"
		;;
	esac
	purge_KUAL_cache
}
#}}}
toggle_store_button () { #{{{
# replace/restore FW 5.x Store button
# 注意：原版此处为 `local verb=... btnpath=... bak`（ash 内置 local 声明变量）。
# 去掉 local 后若仍把 bak 写在同一行，POSIX sh 会把 bak 当作命令执行，
# 并使前置赋值只作用于该命令的环境，导致 btnpath 为空、功能失效。故逐行赋值。
	verb="${1}"
	btnpath="$(store_button_filepath)"
	bak=''
	[ -e "${btnpath}" ] || { msg_fail "Store button file not found (unsupported firmware)"; return; }
	bak="${btnpath}.KUAL_bak"
	case "${verb}" in
		"restore" )
			msg_wait "Restoring Store button"
			[ -e "${bak}" ] || { msg_ok "Store button not replaced, nothing to restore"; return; }
			if mntroot rw && mv -f "${bak}" "${btnpath}" ; then
				mntroot ro
				msg_ok "Store button restored - please restart your Kindle"
			else
				mntroot ro
				msg_fail "Restore failed (mntroot/mv error)"
			fi
		;;
		"replace" )
			msg_wait "Replacing Store button with KUAL"
			[ -e "$bak" ] && { msg_ok "Store button already replaced"; return; }
			needle='app://com.lab126.store'
			if ! grep -q -m 1 -F "${needle}" "${btnpath}" ; then
				msg_fail "Store button unchanged (target string not found)"
				return
			fi
			repl="$(KUAL_filepath)"
			if [ "${repl}" = "com.mobileread.ixtab.kindlelauncher" ] ; then
				if mntroot rw && mv "${btnpath}" "${bak}" ; then
					sed -re "s#([\"'])${needle}(['\"])#\1app://${repl}\2#" "${bak}" > "${btnpath}"
					mntroot ro
					msg_ok "Store button replaced - please restart your Kindle"
				else
					mntroot ro
					msg_fail "Replace failed (mntroot/mv error)"
				fi
			else
				[ -e "${repl}" ] || { msg_fail "KUAL booklet/kindlet not found"; return; }
				if mntroot rw && mv "${btnpath}" "${bak}" ; then
					sed -re "s#([\"'])${needle}(['\"])#\1file://${repl}\2#" "${bak}" > "${btnpath}"
					mntroot ro
					msg_ok "Store button replaced - please restart your Kindle"
				else
					mntroot ro
					msg_fail "Replace failed (mntroot/mv error)"
				fi
			fi
		;;
	esac
}
#}}}

# main
eval "${@}"

# vim:fdm=marker:
