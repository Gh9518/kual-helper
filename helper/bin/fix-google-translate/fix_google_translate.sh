#!/bin/sh

# 由 $0 的真实路径定位插件根目录（向上查找 config.xml），不依赖调用方的工作目录；
# 找不到时回退到标准安装路径。KUAL_HOME 可由测试环境覆盖。
_kh=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || _kh=''
case "$_kh" in ''|/) _kh=/mnt/us/extensions/helper ;; esac
while [ "$_kh" != / ] && [ ! -f "$_kh/config.xml" ]; do _kh=$(dirname "$_kh"); done
[ -f "$_kh/config.xml" ] || _kh=/mnt/us/extensions/helper
KUAL_HOME=${KUAL_HOME:-$_kh}

# 修复谷歌：自动从 GitHub 获取「国内可用的谷歌翻译 IP」列表，逐个测试可用性，
#           按响应速度排序后写入 /etc/hosts（最快的生效，其余作备用注释）。
# IP 列表源：hcfyapp/google-translate-cn-ip（社区维护，专供 translate.googleapis.com）
#   https://github.com/hcfyapp/google-translate-cn-ip
# 备选源全部不可用时使用内置兜底列表，保证离线也能尝试。
# 运行中提示与结束提示由 bin/msg.sh 统一给出。

if [ -r "$KUAL_HOME/bin/config.sh" ]; then
    . "$KUAL_HOME/bin/config.sh"
else
    KINDLE_PATH=/mnt/us
    PYTHON3=$(command -v python3 2>/dev/null)
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
fi

TARGET_DOMAIN=translate.googleapis.com
HOSTS_FILE=/etc/hosts
COMMENT="# Fix Google Translate CN"

GREP_CMD=/bin/grep
SED_CMD=/bin/sed
CURL_CMD=/usr/bin/curl
[ -x "$GREP_CMD" ] || GREP_CMD=$(command -v grep 2>/dev/null)
[ -x "$SED_CMD" ]  || SED_CMD=$(command -v sed 2>/dev/null)
[ -x "$CURL_CMD" ] || CURL_CMD=$(command -v curl 2>/dev/null)

API='https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=fr&dt=t&dj=1&q=hello'

#--------------------------------------------------------------
# 多个 GitHub / GitHub-CDN 备选源：逐个测速，选「最快且能返回有效 IP 列表」的一个。
# 如需增加备选，按下面格式每行加一个 URL 即可（内容为纯 IP 列表或 hosts 格式均可）。
#--------------------------------------------------------------
IP_SOURCES='https://raw.githubusercontent.com/hcfyapp/google-translate-cn-ip/main/ips.txt
https://raw.githubusercontent.com/hcfyapp/google-translate-cn-ip/master/packages/google-translate-ip/ips.txt
https://unpkg.com/@hcfy/google-translate-ip/ips.txt
https://fastly.jsdelivr.net/npm/@hcfy/google-translate-ip/ips.txt
https://cdn.jsdelivr.net/npm/@hcfy/google-translate-ip/ips.txt
https://cdn.jsdelivr.net/gh/hcfyapp/google-translate-cn-ip@master/packages/google-translate-ip/ips.txt'

# 兜底：GitHub 源全部不可达时仍可逐个测试的静态候选
FALLBACK_IPS='142.250.4.90
142.250.157.90
142.250.96.90
172.217.203.90
172.253.114.90
142.250.113.90
108.177.97.100
216.58.227.65'

FETCH_TO=8      # 拉取 IP 列表超时
CONNECT_TO=3    # 单个 IP 连接超时
MAX_TO=6        # 单个 IP 总超时
BATCH=6         # 每批并行测试多少个 IP
MAX_TRIES=${KUAL_GT_MAX_TRIES:-0}   # 0 = 测试全部候选；并行分批控制总时长
WANT=3          # 找到这么多个可用 IP 就提前结束
case "$MAX_TRIES" in ''|*[!0-9]*) MAX_TRIES=0 ;; esac

# CURL_CMD 可能为空（command -v 失败）或指向不可执行文件，任一情况都该停止。
if [ -z "$CURL_CMD" ] || [ ! -x "$CURL_CMD" ]; then
    msg_fail "curl not found on Kindle"
    exit 0
fi

# 运行时防锁屏：逐个测 IP 在真机上可能持续数分钟，期间禁止 Kindle 休眠，
# 避免脚本被冻结、WiFi 掉线导致测速中断。结束时自动恢复原状态。
if [ -r "$KUAL_HOME/bin/nolock.sh" ]; then
    . "$KUAL_HOME/bin/nolock.sh"
else
    nolock_begin() { return 0; }
    nolock_end()   { return 0; }
fi
GT_TMPD=''
GT_OWNDIR=1
_gt_cleanup() {
    nolock_end
    if [ -n "$GT_TMPD" ]; then
        # 自建目录可整体删除；若退化到 /tmp 本身，只删本进程的结果文件。
        if [ "$GT_OWNDIR" = 1 ]; then
            rm -rf "$GT_TMPD"
        else
            rm -f "$GT_TMPD"/r.$$.* 2>/dev/null
        fi
    fi
    return 0
}

# 从 hosts 中清掉本工具写入的所有行，保留其它内容。
# 所有自写行（标题/统计/生效/备用）都带 COMMENT 标记或域名，
# 且不再单独写入孤立空行，避免每跑一次 hosts 就累积一行。
clean_hosts() {
    TMP="$HOSTS_FILE.kualtmp"
    $GREP_CMD -v -F "$TARGET_DOMAIN" "$HOSTS_FILE" 2>/dev/null \
        | $GREP_CMD -v -F "$COMMENT" > "$TMP" || : > "$TMP"
    mv "$TMP" "$HOSTS_FILE" 2>/dev/null
    chmod 644 "$HOSTS_FILE" 2>/dev/null
}

# -d：仅删除规则（保留备用，不出现在菜单里）
if [ "$1" = "-d" ]; then
    mntroot rw 2>/dev/null
    clean_hosts
    mntroot ro 2>/dev/null
    msg_ok "Google Translate hosts rule removed"
    exit 0
fi

msg_wait "Testing Google Translate IPs"

nolock_begin
trap '_gt_cleanup' EXIT
trap 'exit 130' INT TERM HUP

#--------------------------------------------------------------
# 1) 自动查找：逐个测速 GitHub 备选源，取最快且返回有效 IP 列表的那个
#--------------------------------------------------------------
BEST_TIME=999
BEST_IPS=''
for u in $IP_SOURCES; do
    body=$($CURL_CMD -sL --connect-timeout 3 --max-time $FETCH_TO \
        -w '\n%{time_total}' "$u" 2>/dev/null)
    [ -n "$body" ] || continue
    t=$(printf '%s' "$body" | $SED_CMD -n '$p')
    case "$t" in ''|*[!0-9.]*) t=99.999 ;; esac
    ips=$(printf '%s' "$body" \
        | $GREP_CMD -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' \
        | awk '!seen[$0]++')
    [ -n "$ips" ] || continue
    if awk "BEGIN{exit !($t < $BEST_TIME)}"; then
        BEST_TIME=$t
        BEST_IPS=$ips
    fi
done

if [ -n "$BEST_IPS" ]; then
    IP_LIST=$BEST_IPS
    msg_info "Fastest IP source selected (${BEST_TIME}s)"
else
    IP_LIST=$FALLBACK_IPS
    msg_info "GitHub sources unreachable, using built-in IPs"
fi

TOTAL=$(printf '%s\n' "$IP_LIST" | $GREP_CMD -c '.')
if [ "$MAX_TRIES" -gt 0 ] && [ "$TOTAL" -gt "$MAX_TRIES" ]; then
    msg_info "Testing up to $MAX_TRIES of $TOTAL IPs ($BATCH parallel)..."
else
    msg_info "Testing $TOTAL candidate IPs ($BATCH parallel)..."
fi

#--------------------------------------------------------------
# 2) 并行分批测试：每个后台任务把「耗时 IP」写入临时文件。
#    命中条件为 http_code=200 且响应正文含 bonjour（大小写不敏感），
#    不再依赖固定的 "trans":"bonjour" 字段，避免接口格式变化造成假阴性。
#    旧版串行只测前 18 个，这里覆盖全部候选；总耗时约为 总数/BATCH × 单次超时。
#--------------------------------------------------------------
GT_TMPD=/tmp/kual_gt_$$
GT_OWNDIR=1
mkdir -p "$GT_TMPD" 2>/dev/null || { GT_TMPD=/tmp; GT_OWNDIR=0; }

RESULTS=''
TRIES=0
FOUND=0
SEQ=0
IN_BATCH=0

_gt_collect() {
    wait
    for _f in "$GT_TMPD"/r.$$.*; do
        [ -f "$_f" ] || continue
        IFS=' ' read -r _gt_t _gt_ip < "$_f"
        rm -f "$_f"
        [ -n "$_gt_ip" ] || continue
        RESULTS=$(printf '%s\n%s %s' "$RESULTS" "$_gt_t" "$_gt_ip")
        FOUND=$((FOUND + 1))
    done
    IN_BATCH=0
    return 0
}

for ip in $IP_LIST; do
    [ "$FOUND" -ge "$WANT" ] && break
    if [ "$MAX_TRIES" -gt 0 ] && [ "$TRIES" -ge "$MAX_TRIES" ]; then break; fi
    TRIES=$((TRIES + 1))
    SEQ=$((SEQ + 1))
    (
        res=$($CURL_CMD -s --connect-timeout $CONNECT_TO --max-time $MAX_TO \
            -w '\n%{http_code}|%{time_total}' \
            --resolve "$TARGET_DOMAIN:443:$ip" "$API" 2>/dev/null)
        meta=$(printf '%s' "$res" | $SED_CMD -n '$p')
        body=$(printf '%s' "$res" | $SED_CMD '$d')
        code=${meta%%|*}
        gt_t=${meta##*|}
        [ "$code" = 200 ] || exit 0
        printf '%s' "$body" | $GREP_CMD -qi 'bonjour' || exit 0
        case "$gt_t" in ''|*[!0-9.]*) gt_t=9.999 ;; esac
        printf '%s %s\n' "$gt_t" "$ip" > "$GT_TMPD/r.$$.$SEQ.$ip"
    ) &
    IN_BATCH=$((IN_BATCH + 1))
    [ "$IN_BATCH" -ge "$BATCH" ] && _gt_collect
done
_gt_collect

RANKED=$(printf '%s\n' "$RESULTS" | $GREP_CMD -E '^[0-9]' | sort -n)
FASTEST_IP=$(printf '%s\n' "$RANKED" | $SED_CMD -n '1s/^[^ ]* //p')
FASTEST_TIME=$(printf '%s\n' "$RANKED" | $SED_CMD -n '1s/ .*//p')

mntroot rw 2>/dev/null

if [ -z "$FASTEST_IP" ]; then
    msg_fail "No reachable IP ($TRIES of $TOTAL tested, Google may be blocked on this network)"
    mntroot ro 2>/dev/null
    exit 0
fi

#--------------------------------------------------------------
# 3) 写入 /etc/hosts：最快的作生效行，其余可用 IP 记为备用注释
#--------------------------------------------------------------
clean_hosts
{
    # 每一行都带 COMMENT 标记或域名，保证下次 clean_hosts 能完整清除，
    # 不再写入不带标记的孤立空行 / 统计行。
    printf '%s\n' "$COMMENT"
    printf '%s tested=%s reachable=%s fastest=%ss %s\n' \
        "$COMMENT" "$TRIES" "$FOUND" "$FASTEST_TIME" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    printf '%s %s\n' "$FASTEST_IP" "$TARGET_DOMAIN"
    printf '%s\n' "$RANKED" | tail -n +2 | while read t ip; do
        [ -n "$ip" ] && printf '# backup %s %s\n' "$ip" "$TARGET_DOMAIN"
    done
} >> "$HOSTS_FILE"
chmod 644 "$HOSTS_FILE" 2>/dev/null

mntroot ro 2>/dev/null
msg_ok "Fastest IP $FASTEST_IP written (${FASTEST_TIME}s, $FOUND/$TRIES ok)"
nolock_end
