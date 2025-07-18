#!/bin/bash

COOR_LOG="coor_output"
INTERFACE="eth0"

# 1. coor_output에서 UL/DL 배열 파싱
ul_line=$(grep '^UL:' "$COOR_LOG" | tail -1)
dl_line=$(grep '^DL:' "$COOR_LOG" | tail -1)

# 배열로 변환
IFS=' ' read -r -a UL_LIST <<< "${ul_line#UL: }"
IFS=' ' read -r -a DL_LIST <<< "${dl_line#DL: }"

# 2. Block index -> IP 매핑 추출
declare -A block_ip_map
block_idx=0
curr_block=""

while read -r line; do
    if [[ "$line" =~ filename:\ (/[^[:space:]]+) ]]; then
        curr_block="${BASH_REMATCH[1]}"
    fi
    if [[ "$line" =~ getLocation\.return:\ ([^[:space:]]+) ]]; then
        ip="${BASH_REMATCH[1]}"
        block_ip_map[$block_idx]="$ip"
        ((block_idx++))
    fi
done < "$COOR_LOG"

# 3. 각 IP에 wondershaper로 대역폭 설정
for i in "${!UL_LIST[@]}"; do
    ul="${UL_LIST[$i]}"
    dl="${DL_LIST[$i]}"
    ip="${block_ip_map[$i]}"

    if [[ -n "$ip" ]]; then
        echo "[INFO] Block $i -> IP $ip, UL=$ul DL=$dl"
        ssh "$ip" "sudo wondershaper $INTERFACE $ul $dl"
    else
        echo "[WARN] Block $i has no IP mapping"
    fi
done
