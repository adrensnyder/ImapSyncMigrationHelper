###################################################################
# Copyright (c) 2026 AdrenSnyder https://github.com/adrensnyder
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# DISCLAIMER:
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
###################################################################

#!/bin/bash
set -u

LOGPATH=${1:-}
RED='\033[0;31m'
NC='\033[0m'

human_bytes() {
    awk -v b="$1" '
    function human(x) {
        split("B KiB MiB GiB TiB", u, " ");
        i=1;
        while (x >= 1024 && i < 5) {
            x /= 1024;
            i++;
        }
        return sprintf("%.3f %s", x, u[i]);
    }
    BEGIN { print human(b) }'
}

if [[ -z "$LOGPATH" ]]; then
    echo "Uso: $0 /percorso/logdir"
    exit 1
fi

if [[ ! -d "$LOGPATH" ]]; then
    echo "Percorso non valido: $LOGPATH"
    exit 1
fi

shopt -s nullglob
FILES=( "$LOGPATH"/*%* )

if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "Nessun file *%* trovato in: $LOGPATH"
    exit 0
fi

PREFIXES=()
for f in "${FILES[@]}"; do
    base="${f##*/}"
    prefix="${base%%\%*}"
    PREFIXES+=( "$prefix" )
done

mapfile -t LIST_UNIQUE < <(printf "%s\n" "${PREFIXES[@]}" | sort -u)

LASTLOGS=()

echo ""
echo -e "- ${RED}File list${NC}"
for p in "${LIST_UNIQUE[@]}"; do
    LASTLOG=$(ls -1 -r -- "$LOGPATH/$p%"* 2>/dev/null | head -n1)
    [[ -n "$LASTLOG" ]] && LASTLOGS+=( "$LASTLOG" )
    echo "$p -> $LASTLOG"
done

echo ""
echo -e "- ${RED}Dry size estimates${NC}"
echo "account|host1_size|host2_size|copy_estimated|host2_final_estimated"

GRAND_HOST1=0
GRAND_HOST2=0
GRAND_COPY=0
GRAND_FINAL=0

for file in "${LASTLOGS[@]}"; do
    base="${file##*/}"
    account="${base%%\%*}"

    HOST1_TOTAL=$(grep -a "Host1 Total size:" "$file" | tail -n1 | sed -E 's/.*: *([0-9]+) bytes.*/\1/')
    HOST2_TOTAL=$(grep -a "Host2 Total size:" "$file" | tail -n1 | sed -E 's/.*: *([0-9]+) bytes.*/\1/')
    BYTES_SKIPPED=$(grep -a "Total bytes skipped" "$file" | tail -n1 | sed -E 's/.*: *([0-9]+) .*/\1/')

    [[ -z "$HOST1_TOTAL" ]] && HOST1_TOTAL=0
    [[ -z "$HOST2_TOTAL" ]] && HOST2_TOTAL=0
    [[ -z "$BYTES_SKIPPED" ]] && BYTES_SKIPPED=0

    COPY_EST=$((HOST1_TOTAL - BYTES_SKIPPED))
    if (( COPY_EST < 0 )); then
        COPY_EST=0
    fi

    HOST2_FINAL=$((HOST2_TOTAL + COPY_EST))

    GRAND_HOST1=$((GRAND_HOST1 + HOST1_TOTAL))
    GRAND_HOST2=$((GRAND_HOST2 + HOST2_TOTAL))
    GRAND_COPY=$((GRAND_COPY + COPY_EST))
    GRAND_FINAL=$((GRAND_FINAL + HOST2_FINAL))

    echo "${account}|$(human_bytes "$HOST1_TOTAL")|$(human_bytes "$HOST2_TOTAL")|$(human_bytes "$COPY_EST")|$(human_bytes "$HOST2_FINAL")"
done

echo ""
echo -e "- ${RED}Totals${NC}"
echo "host1_total|$(human_bytes "$GRAND_HOST1")"
echo "host2_total|$(human_bytes "$GRAND_HOST2")"
echo "copy_estimated_total|$(human_bytes "$GRAND_COPY")"
echo "host2_final_estimated_total|$(human_bytes "$GRAND_FINAL")"
