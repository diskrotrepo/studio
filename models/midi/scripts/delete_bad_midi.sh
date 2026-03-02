#!/usr/bin/env bash
# Watch processing and tokenizing logs for FAILED/SKIPPED/TIMEOUT entries
# and delete those MIDI files as they appear.
# Usage: ./scripts/delete_bad_midi.sh [--dry-run]

cd "$(dirname "$0")/.." || exit 1

LOGS=("midi_processing.log" "midi_tokenizing.log")
DRY_RUN=false
COUNT=0

if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "Dry run mode - files will NOT be deleted"
fi

try_delete() {
    local line="$1"
    local filepath

    if [[ "$line" =~ ^(FAILED|SKIPPED|TIMEOUT):[[:space:]](.+)[[:space:]]\((.+)\)$ ]]; then
        filepath="${BASH_REMATCH[2]}"
        if [[ -f "$filepath" ]]; then
            if $DRY_RUN; then
                echo "[dry-run] Would delete: $filepath"
            else
                rm "$filepath" && echo "Deleted: $filepath"
                ((COUNT++))
            fi
        fi
    fi
}

# Wait for at least one log to exist
echo "Waiting for log files..."
while true; do
    for log in "${LOGS[@]}"; do
        [[ -f "$log" ]] && break 2
    done
    sleep 1
done

# Process existing entries
for log in "${LOGS[@]}"; do
    if [[ -f "$log" ]]; then
        echo "Processing existing entries in $log..."
        while IFS= read -r line; do
            try_delete "$line"
        done < "$log"
    fi
done
echo "Done with existing entries ($COUNT deleted so far)"

# Build tail command for all existing logs
TAIL_ARGS=()
for log in "${LOGS[@]}"; do
    [[ -f "$log" ]] && TAIL_ARGS+=("$log")
done

echo "Watching for new entries..."
tail -n 0 -f "${TAIL_ARGS[@]}" | while IFS= read -r line; do
    try_delete "$line"
done
