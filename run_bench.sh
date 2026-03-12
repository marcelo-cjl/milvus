#!/bin/bash
# Run benchmark: bulk import dataset into Milvus and collect build timing stats.
#
# Usage:
#   ./run_bench.sh -s sift500k                          # bulk import to local milvus
#   ./run_bench.sh -s sift50M -t g6                     # specify instance type for output filename
#   ./run_bench.sh -s sift5M -u http://10.15.3.93:19530 # import to remote milvus
#
# Output: stats_{dataset}_{type}.txt (default type: g6)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/standalone.log"
MILVUS_URI="http://localhost:19530"
INSTANCE_TYPE="g6"

usage() {
    echo "Usage: $0 -s <dataset> [-t <instance_type>] [-u <milvus_uri>]"
    echo "  Supported datasets: sift500k, sift5M, cohere1M, cohere10M, sift50M, openai500k, openai5M"
    echo "  -t  Instance type label for output filename (default: g6)"
    echo "  -u  Milvus URI (default: http://localhost:19530)"
    exit 1
}

ALL_DATASETS="sift500k sift5M sift50M cohere1M cohere10M openai500k openai5M"

DATASET=""
while getopts "s:t:u:" opt; do
    case $opt in
        s) DATASET="$OPTARG" ;;
        t) INSTANCE_TYPE="$OPTARG" ;;
        u) MILVUS_URI="$OPTARG" ;;
        *) usage ;;
    esac
done

# If no dataset specified, run all
if [[ -z "$DATASET" ]]; then
    DATASETS="$ALL_DATASETS"
else
    # Validate dataset name
    case "$DATASET" in
        sift500k|sift5M|sift50M|cohere1M|cohere10M|openai500k|openai5M) ;;
        *)
            echo "Error: unsupported dataset '$DATASET'"
            echo "Supported: $ALL_DATASETS"
            exit 1
            ;;
    esac
    DATASETS="$DATASET"
fi

run_one_dataset() {
    local ds="$1"
    local OUTPUT_FILE="${SCRIPT_DIR}/stats_${ds}_${INSTANCE_TYPE}.txt"

    # Record timestamp before run (used to filter log lines from this run only)
    local BEFORE_TS
    BEFORE_TS=$(date -u +"%Y/%m/%d %H:%M:%S")
    echo "=== Benchmark: $ds (instance: $INSTANCE_TYPE) ==="
    echo "  Milvus URI: $MILVUS_URI"
    echo "  Start time: $BEFORE_TS"
    echo "  Output: $OUTPUT_FILE"
    echo ""

    # Step 1: Bulk import data and build index
    echo "[1/2] Bulk importing and building index..."
    python3 "${SCRIPT_DIR}/bulk_load.py" -s "$ds" --uri "$MILVUS_URI"

    echo ""
    echo "[2/2] Parsing build timing from log ..."
    python3 "${SCRIPT_DIR}/parse_build_timing.py" "$LOG_FILE" \
        --after "$BEFORE_TS" \
        -o "$OUTPUT_FILE"

    echo ""
    echo "=== Done: $ds results in $OUTPUT_FILE ==="
    echo ""
}

for ds in $DATASETS; do
    run_one_dataset "$ds"
done
