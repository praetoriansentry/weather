#!/usr/bin/env bash
set -euo pipefail

lat=42.3424
lon=-71.1197
hours=48
out=weather

while [[ $# -gt 0 ]]; do
    case "$1" in
        --lat)   lat=$2;   shift 2 ;;
        --lon)   lon=$2;   shift 2 ;;
        --hours) hours=$2; shift 2 ;;
        --out)   out=$2;   shift 2 ;;
        -h|--help)
            cat <<EOF
Usage: $0 [--lat LAT] [--lon LON] [--hours N] [--out BASENAME]
Defaults: lat=42.3424 lon=-71.1197 hours=48 out=weather
EOF
            exit 0 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

for cmd in curl xmllint gnuplot awk paste; do
    command -v "$cmd" >/dev/null || { echo "missing required command: $cmd" >&2; exit 1; }
done

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

xml=$workdir/weather.xml
tsv=$workdir/data.tsv

url="https://forecast.weather.gov/MapClick.php?lat=${lat}&lon=${lon}&FcstType=digitalDWML"
echo "fetching $url" >&2
curl -fsS "$url" -o "$xml"

extract_leaves() {
    # Emit one value per line; empty for xsi:nil. $1 is an xpath matching leaf elements
    # (e.g. <value>34</value>, <start-valid-time>2026-04-19T08:00:00-04:00</start-valid-time>,
    #  <value xsi:nil="true"/>).
    { xmllint --xpath "$1" "$xml" 2>/dev/null || true; } \
        | awk '
            BEGIN { RS="</[a-zA-Z-]+>" }
            {
                if ($0 ~ /xsi:nil=.true./) { print ""; next }
                if (match($0, /<[a-zA-Z-]+[^>]*>/)) {
                    s = substr($0, RSTART+RLENGTH)
                    gsub(/^[ \t\n]+|[ \t\n]+$/, "", s)
                    if (s != "") print s
                }
            }'
}

extract_leaves "//time-layout/start-valid-time" | head -n "$hours" > "$workdir/t.col"
n_rows=$(wc -l < "$workdir/t.col")

pad_col() {
    # Usage: pad_col <xpath> <outfile>. Truncates/pads to $n_rows lines (empty for missing).
    extract_leaves "$1" \
        | awk -v n="$n_rows" 'NR<=n {print} END {for (i=NR+1; i<=n; i++) print ""}' > "$2"
}

pad_col "//temperature[@type='hourly']/value"           "$workdir/temp.col"
pad_col "//temperature[@type='dew point']/value"        "$workdir/dewpt.col"
pad_col "//temperature[@type='heat index']/value"       "$workdir/heatidx.col"
pad_col "//wind-speed[@type='sustained']/value"         "$workdir/wind.col"
pad_col "//wind-speed[@type='gust']/value"              "$workdir/gust.col"
pad_col "//direction[@type='wind']/value"               "$workdir/winddir.col"
pad_col "//cloud-amount[@type='total']/value"           "$workdir/cloud.col"
pad_col "//humidity[@type='relative']/value"            "$workdir/rh.col"
pad_col "//probability-of-precipitation/value"          "$workdir/pop.col"
pad_col "//hourly-qpf/value"                            "$workdir/qpf.col"

# thunder level: one line per <weather-conditions>; map thunderstorms coverage to 0-4
{ xmllint --xpath "//weather/weather-conditions" "$xml" 2>/dev/null || true; } \
    | awk -v n="$n_rows" '
        NR > n { exit }
        /weather-type="thunderstorms"/ {
            match($0, /weather-type="thunderstorms"[^\/]*coverage="[^"]*"/)
            s = substr($0, RSTART, RLENGTH)
            match(s, /coverage="[^"]*"/)
            c = substr(s, RSTART+10, RLENGTH-11)
            if (c == "slight chance") print 1
            else if (c == "chance")    print 2
            else if (c == "likely")    print 3
            else if (c == "occasional") print 4
            else print 0
            next
        }
        { print 0 }
        END { for (i=NR+1; i<=n; i++) print 0 }
    ' > "$workdir/thunder.col"

paste -d $'\t' \
    "$workdir/t.col" \
    "$workdir/temp.col" \
    "$workdir/dewpt.col" \
    "$workdir/heatidx.col" \
    "$workdir/wind.col" \
    "$workdir/gust.col" \
    "$workdir/winddir.col" \
    "$workdir/cloud.col" \
    "$workdir/rh.col" \
    "$workdir/pop.col" \
    "$workdir/qpf.col" \
    "$workdir/thunder.col" \
    > "$tsv"

rows=$(wc -l < "$tsv")
echo "extracted $rows hourly rows" >&2

if [[ $rows -lt 2 ]]; then
    echo "not enough data rows; aborting" >&2
    exit 2
fi

t_start=$(head -n1 "$tsv" | cut -f1)
t_end=$(tail -n1 "$tsv" | cut -f1)
day_label=$(date -d "$t_start" +"%a, %b %d %Y" 2>/dev/null || echo "Forecast")
location_label="${lat}, ${lon}"

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
gp="$script_dir/meteogram.gp"

render() {
    local term=$1 ext=$2
    gnuplot \
        -e "term_name='$term'" \
        -e "outfile='${out}.${ext}'" \
        -e "datafile='$tsv'" \
        -e "t_start='$t_start'" \
        -e "t_end='$t_end'" \
        -e "day_label='$day_label'" \
        -e "location_label='$location_label'" \
        "$gp"
    echo "wrote ${out}.${ext}" >&2
}

render pngcairo png &
render svg      svg &
wait
