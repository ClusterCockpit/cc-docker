#!/bin/bash

set -euo pipefail

NEW_CHECKPOINTS='../data/cc-metric-store/checkpoints'
VERBOSE=1
INFLUX_HOST='http://0.0.0.0:8181'

HEADERS=(
    -H "Content-Type: text/plain; charset=utf-8"
    -H "Accept: application/json"
)

checkp_clusters=()
while IFS= read -r -d '' dir; do
    checkp_clusters+=("$(basename "$dir")")
done < <(find "$NEW_CHECKPOINTS" -mindepth 1 -maxdepth 1 -type d \! -name 'job-archive' -print0)

for cluster in "${checkp_clusters[@]}"; do
    echo "Starting to read updated checkpoint-files into influx for $cluster"

    while IFS= read -r -d '' level1_dir; do
        level1=$(basename "$level1_dir")
        node_source="$NEW_CHECKPOINTS/$cluster/$level1"

        mapfile -t files < <(find "$node_source" -type f -name '*.json' | sort -V)
        # if [[ ${#files[@]} -ne 14 ]]; then
        #     continue
        # fi

        node_measurement=""
        for file in "${files[@]}"; do
            rawstr=$(<"$file")

            while IFS= read -r metric; do
                start=$(jq -r ".metrics[\"$metric\"].start" <<<"$rawstr")
                timestep=$(jq -r ".metrics[\"$metric\"].frequency" <<<"$rawstr")

                while IFS= read -r index_value; do
                    index=$(awk -F: '{print $1}' <<<"$index_value")
                    value=$(awk -F: '{print $2}' <<<"$index_value")

                    if [[ -n "$value" && "$value" != "null" ]]; then
                        timestamp=$((start + (timestep * index)))
                        node_measurement+="$metric,cluster=$cluster,hostname=$level1,type=node value=$value $timestamp\n"
                    fi
                done < <(jq -r ".metrics[\"$metric\"].data | to_entries | map(\"\(.key):\(.value // \"null\")\") | .[]" <<<"$rawstr")
            done < <(jq -r '.metrics | keys[]' <<<"$rawstr")
        done

        if [[ -n "$node_measurement" ]]; then
            while IFS= read -r  chunk; do
                response_code=$(curl -s -o /dev/null -w "%{http_code}" "${HEADERS[@]}" --data-binary "$chunk" "$INFLUX_HOST/api/v2/write?bucket=mydb&precision=s")
                if [[ "$response_code" == "204" ]]; then
                    [[ "$VERBOSE" -eq 1 ]] && echo "INFLUX API WRITE: CLUSTER $cluster HOST $level1"
                elif [[ "$response_code" != "422" ]]; then
                    echo "INFLUX API WRITE ERROR CODE $response_code"
                fi
            done < <(echo -e "$node_measurement" | split -l 1000 --filter='cat')
        fi
        echo "Done for : "$node_source
    done < <(find "$NEW_CHECKPOINTS/$cluster" -mindepth 1 -maxdepth 1 -type d -print0)
done

echo "Done for influx"
