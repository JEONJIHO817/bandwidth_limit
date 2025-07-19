#!/bin/bash

COOR_LOG="coor_output"
INTERFACE="eth0"

# 1. coor_output에서 UL/DL 배열 파싱
UL=()
DL=()
while read -r line; do
    if [[ "$line" =~ ^UL:\ (.*) ]]; then
        IFS=' ' read -r -a UL <<< "${BASH_REMATCH[1]}"
    fi
    if [[ "$line" =~ ^DL:\ (.*) ]]; then
        IFS=' ' read -r -a DL <<< "${BASH_REMATCH[1]}"
    fi
done < "$COOR_LOG"

# 2. block number → IP 매핑 추출
declare -A block_ip_map
current_block=""

while read -r line; do
    if [[ "$line" =~ filename:\ .*_oecobj_([0-9]+) ]]; then
        current_block="${BASH_REMATCH[1]}"
    fi
    if [[ "$line" =~ getLocation.return:\ ([0-9.]+) ]]; then
        ip="${BASH_REMATCH[1]}"
        block_ip_map["$current_block"]="$ip"
    fi
done < "$COOR_LOG"

# 3. UL/DL 제약 적용
for block in "${!block_ip_map[@]}"; do
    ip="${block_ip_map[$block]}"
    ul="${UL[$block]}"
    dl="${DL[$block]}"
    if [[ -n "$ip" && -n "$ul" && -n "$dl" ]]; then
        echo "[INFO] Block $block -> IP $ip, UL=$ul DL=$dl"
        ssh "$ip" "sudo wondershaper $INTERFACE $ul $dl"
    else
        echo "[WARN] Block $block has missing UL/DL/IP mapping"
    fi
done
