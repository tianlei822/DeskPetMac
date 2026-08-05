#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "usage: $0 <pid> [duration-seconds=300] [interval-seconds=5]" >&2
}

if [[ $# -lt 1 || $# -gt 3 ]]; then
    usage
    exit 2
fi

pid="$1"
duration="${2:-300}"
interval="${3:-5}"

if [[ ! "${pid}" =~ ^[0-9]+$ ]] ||
   [[ ! "${duration}" =~ ^[1-9][0-9]*$ ]] ||
   [[ ! "${interval}" =~ ^[1-9][0-9]*$ ]]; then
    usage
    exit 2
fi

if ! ps -p "${pid}" >/dev/null 2>&1; then
    echo "error: process ${pid} is not running" >&2
    exit 1
fi

cpu_samples=()
rss_samples=()
energy_samples=()
started_at="${SECONDS}"
deadline=$((started_at + duration))
sample_index=0

echo "sample,timestamp,cpu_percent,rss_kb,energy_impact"

while (( SECONDS < deadline )); do
    sample_started_at="${SECONDS}"
    top_output="$(top -l 2 -s 1 -n 1 -pid "${pid}" -stats pid,cpu,power)"
    metrics="$(printf '%s\n' "${top_output}" | awk -v target="${pid}" '
        $1 == target { cpu = $2; energy = $3 }
        END {
            if (cpu == "" || energy == "") exit 1
            print cpu, energy
        }
    ')"
    read -r cpu energy <<<"${metrics}"
    rss="$(ps -p "${pid}" -o rss= | awk '{$1=$1; print}')"

    if [[ -z "${rss}" ]]; then
        echo "error: process ${pid} exited during sampling" >&2
        exit 1
    fi

    sample_index=$((sample_index + 1))
    cpu_samples+=("${cpu}")
    rss_samples+=("${rss}")
    energy_samples+=("${energy}")
    printf '%d,%s,%s,%s,%s\n' \
        "${sample_index}" \
        "$(date '+%Y-%m-%dT%H:%M:%S%z')" \
        "${cpu}" \
        "${rss}" \
        "${energy}"

    elapsed=$((SECONDS - sample_started_at))
    remaining=$((interval - elapsed))
    if (( remaining > 0 && SECONDS < deadline )); then
        sleep "${remaining}"
    fi
done

summarize() {
    awk '
        NR == 1 { min = $1; max = $1 }
        {
            sum += $1
            if ($1 < min) min = $1
            if ($1 > max) max = $1
        }
        END {
            if (NR == 0) exit 1
            printf "%.2f,%.2f,%.2f", sum / NR, min, max
        }
    '
}

cpu_summary="$(printf '%s\n' "${cpu_samples[@]}" | summarize)"
rss_summary="$(printf '%s\n' "${rss_samples[@]}" | summarize)"
energy_summary="$(printf '%s\n' "${energy_samples[@]}" | summarize)"

echo "summary,samples,duration_seconds,average,minimum,maximum"
printf 'cpu,%d,%d,%s\n' "${sample_index}" "${duration}" "${cpu_summary}"
printf 'rss_kb,%d,%d,%s\n' "${sample_index}" "${duration}" "${rss_summary}"
printf 'energy_impact,%d,%d,%s\n' "${sample_index}" "${duration}" "${energy_summary}"
