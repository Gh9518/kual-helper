#!/bin/ash -
# do.sh - KUAL add-ons processor by stepk, version 20130507,a
# $Id: do.sh 13380 2016-07-19 01:01:28Z NiLuJe $

# kindle AWK is busybox AWK not gawk
[ -f /bin/awk ] || alias awk='/bin/busybox awk'

CONFIGPATH="/mnt/us/extensions/KUAL.cfg"

# helpers
config_full_path () { #{{{
	local - a1="${1}"
	if [ -r "${CONFIGPATH}" ] ; then
		echo -n "${CONFIGPATH}"
	elif [ create = "${a1}" ] ; then
		echo "# ${CONFIGFILE##*/} - created on $(date)" > "${CONFIGPATH}" && echo -n "${CONFIGPATH}"
	fi
}
#}}}
get_option () { #{{{ option
	local x
	eval "${1}="
	if [ -r "${CONFIGPATH}" ] ; then
		source "${CONFIGPATH}"
		x="${1}=\"\${KUAL_${1}}\""
		eval ${x}
	fi
}
#}}}
set_option () { #{{{ option value
	local option="${1}" value="${2}" config="$(config_full_path create)" newtext=''
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
	local KT532="/usr/share/webkit-1.0/pillow/javascripts/search_bar.js"
	[ -e "${KT532}" ] && echo -n "${KT532}"
}
#}}}
screen_msg () { #{{{
	eips 2 38 "${*}"
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
	local verb="${1}" btnpath="$(store_button_filepath)" bak
	[ -e "${btnpath}" ] || return # unsupported platform
	bak="${btnpath}.KUAL_bak"
	case "${verb}" in
		"restore" )
			[ -e "${bak}" ] || return # nothing to restore
			mntroot rw && mv -f "${bak}" "${btnpath}"
			mntroot ro
			eips 2 5 -h " BUTTON RESTORED. PLEASE RESTART YOUR KINDLE." # or simply X
		;;
		"replace" )
			[ -e "$bak" ] && return # already replaced
			local needle='app://com.lab126.store'
			if ! grep -q -m 1 -F "${needle}" "${btnpath}" ; then
				eips 5 5 -h " BUTTON UNCHANGED. ANOTHER APP HOLDS IT? "
				return
			fi
			local repl="$(KUAL_filepath)"
			if [ "${repl}" == "com.mobileread.ixtab.kindlelauncher" ] ; then
				if mntroot rw && mv "${btnpath}" "${bak}" ; then
					sed -re "s#([\"'])${needle}(['\"])#\1app://${repl}\2#" "${bak}" > "${btnpath}"
					mntroot ro
					eips 2 5 -h " BUTTON REPLACED. PLEASE RESTART YOUR KINDLE." # or simply X
				fi
			else
				[ -e "${repl}" ] || return # devs renamed KUAL file w/o notice
				if mntroot rw && mv "${btnpath}" "${bak}" ; then
					sed -re "s#([\"'])${needle}(['\"])#\1file://${repl}\2#" "${bak}" > "${btnpath}"
					mntroot ro
					eips 2 5 -h " BUTTON REPLACED. PLEASE RESTART YOUR KINDLE." # or simply X
				fi
			fi
		;;
	esac
}
#}}}

# main
eval "${@}"

# vim:fdm=marker:
