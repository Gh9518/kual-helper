#!/bin/sh
# 修复谷歌：自动从 GitHub 获取「国内可用的谷歌翻译 IP」列表，逐个测试可用性，
#           按响应速度排序后写入 /etc/hosts（最快的生效，其余作备用注释）。
# IP 列表源：hcfyapp/google-translate-cn-ip（社区维护，专供 translate.googleapis.com）
#   https://github.com/hcfyapp/google-translate-cn-ip
# 备选源全部不可用时使用内置兜底列表，保证离线也能尝试。

. ./bin/config.sh

TARGET_DOMAIN=translate.googleapis.com
HOSTS_FILE=/etc/hosts
COMMENT="# Fix Google Translate CN"

GREP_CMD=/bin/grep
SED_CMD=/bin/sed
CURL_CMD=/usr/bin/curl
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
MAX_TRIES=18    # 最多测试多少个 IP（控制真机耗时）
WANT=3          # 找到这么多个可用 IP 就提前结束

# CURL_CMD 可能为空（command -v 失败）或指向不可执行文件，任一情况都该停止。
if [ -z "$CURL_CMD" ] || [ ! -x "$CURL_CMD" ]; then
    print_log 3 '找不到 curl，无法逐个测试 IP。'
    exit 0
fi

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
    print_log 4 '已删除谷歌翻译 IP 规则。'
    exit 0
fi

#--------------------------------------------------------------
# 1) 自动查找：逐个测速 GitHub 备选源，取最快且返回有效 IP 列表的那个
#--------------------------------------------------------------
print_log 3 '正在从 GitHub 获取可用 IP 列表...'

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
    print_log 3 "已选最快源 (${BEST_TIME}s)。"
else
    IP_LIST=$FALLBACK_IPS
    print_log 3 'GitHub 源均不可达，改用内置候选 IP。'
fi

TOTAL=$(printf '%s\n' "$IP_LIST" | $GREP_CMD -c '.')
print_log 3 "共 $TOTAL 个候选 IP，开始逐个测试..."

#--------------------------------------------------------------
# 2) 逐个测试：真实请求翻译接口，只保留能返回译文的 IP，并记录耗时
#--------------------------------------------------------------
RESULTS=''
TRIES=0
FOUND=0
for ip in $IP_LIST; do
    TRIES=$((TRIES + 1))
    res=$($CURL_CMD -s --connect-timeout $CONNECT_TO --max-time $MAX_TO \
        -w '\n%{time_total}' --resolve "$TARGET_DOMAIN:443:$ip" "$API" 2>/dev/null)
    if printf '%s' "$res" | $GREP_CMD -q '"trans":"bonjour"'; then
        t=$(printf '%s' "$res" | $SED_CMD -n '$p')
        case "$t" in ''|*[!0-9.]*) t=9.999 ;; esac
        RESULTS=$(printf '%s\n%s %s' "$RESULTS" "$t" "$ip")
        FOUND=$((FOUND + 1))
        [ "$FOUND" -ge "$WANT" ] && break
    fi
    [ "$TRIES" -ge "$MAX_TRIES" ] && break
done

RANKED=$(printf '%s\n' "$RESULTS" | $GREP_CMD -E '^[0-9]' | sort -n)
FASTEST_IP=$(printf '%s\n' "$RANKED" | $SED_CMD -n '1s/^[^ ]* //p')
FASTEST_TIME=$(printf '%s\n' "$RANKED" | $SED_CMD -n '1s/ .*//p')

mntroot rw 2>/dev/null

if [ -z "$FASTEST_IP" ]; then
    print_log 3 "测试了 $TRIES 个 IP，均无响应，请检查网络后重试。"
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

print_log 3 "写入最快 IP $FASTEST_IP (${FASTEST_TIME}s)；测试 $TRIES 个，可用 $FOUND 个。"
print_log 4 'Done.'
mntroot ro 2>/dev/null
