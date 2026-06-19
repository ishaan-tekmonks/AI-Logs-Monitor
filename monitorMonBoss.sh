#!/bin/bash


set -euo pipefail

# insert secrets here
LOG_FILE=""
GOOGLE_CHAT_WEBHOOK=""

# Store offset in the same directory as LOG_FILE so it is in a known, writable, persistent path
OFFSET_FILE="$(dirname "$LOG_FILE")/monitor.offset"

touch "$OFFSET_FILE"
[ ! -s "$OFFSET_FILE" ] && echo 0 > "$OFFSET_FILE"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

print_message() {
    local status="$1"
    local message="$2"

    echo "=================================================="
    echo "$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$status]"
    echo
    echo "$message"
}

# Helper to escape text properly for a JSON string payload
escape_json_text() {
    local input
    input=$(cat)
    if command -v python3 >/dev/null 2>&1; then
        echo "$input" | python3 -c 'import sys, json; print(json.dumps(sys.stdin.read()))'
    elif command -v python >/dev/null 2>&1; then
        echo "$input" | python -c 'import sys, json; print(json.dumps(sys.stdin.read()))'
    else
        # Fallback to sed-based escaping
        local escaped
        escaped=$(echo -n "$input" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n')
        escaped="${escaped%\\n}"
        echo "\"$escaped\""
    fi
}

send_to_google_chat() {
    local timestamp="$1"
    local userid="$2"
    local appid="$3"
    local question="$4"

    local message="*App:* ${appid}

*Time:* ${timestamp}
*User:* ${userid}

*Question:*
${question}"

    if [ -z "${GOOGLE_CHAT_WEBHOOK:-}" ]; then
        print_message "MESSAGE (WEBHOOK NOT CONFIGURED)" "$message"
        return 0
    fi

    local payload_text
    payload_text=$(escape_json_text <<EOF
$message
EOF
)
    local payload="{\"text\": $payload_text}"

    if curl -s --fail \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$GOOGLE_CHAT_WEBHOOK" >/dev/null
    then
        print_message "GOOGLE CHAT SENT" "$message"
        return 0
    fi

    print_message "GOOGLE CHAT DELIVERY FAILED" "$message"
    return 1
}

current_size=$(stat -c%s "$LOG_FILE")
last_offset=$(cat "$OFFSET_FILE" 2>/dev/null || echo 0)

# Handle log rotation/truncation
if [ "$last_offset" -gt "$current_size" ]; then
    last_offset=0
fi

bytes_to_read=$((current_size - last_offset))

# If no new bytes have been appended, exit early
if [ "$bytes_to_read" -le 0 ]; then
    log "No new logs to process. Offset remains at $last_offset."
    exit 0
fi

failed=0
sent_count=0
while read -r line
do
    timestamp=$(echo "$line" | grep -oP '"ts":"\K[^"]+' || true)
    userid=$(echo "$line" | sed -n 's/.*<id>\(.*\)<\/id>.*/\1/p')
    question=$(echo "$line" | sed -n 's/.*<question>\(.*\)<\/question>.*/\1/p')
    appid=$(echo "$line" | sed -n 's/.*<aiappid>\(.*\)<\/aiappid>.*/\1/p')

    [ -z "$userid" ] && continue
    [ -z "$question" ] && continue
    [ -z "$appid" ] && continue

    if send_to_google_chat "$timestamp" "$userid" "$appid" "$question"; then
        log "Sent message user=$userid app=$appid"
        sent_count=$((sent_count + 1))
    else
        log "Failed to send message user=$userid app=$appid"
        failed=1
    fi

done < <(
    # Read exactly up to current_size, preventing duplicates from logs appended during run
    tail -c +"$((last_offset + 1))" "$LOG_FILE" | head -c "$bytes_to_read" | grep -F "<MONITOR>" || true
)

# Safely record offset as the size we just read up to if no messages failed to send
if [ "$failed" -eq 0 ]; then
    echo "$current_size" > "$OFFSET_FILE"
    log "Completed scan. Offset updated to $current_size"
else
    log "Completed scan with delivery errors. Offset remains at $last_offset to allow retry."
fi

# Signal MonBoss: exit with 1 if there was a delivery failure, or 0 if everything succeeded
if [ "$failed" -eq 1 ]; then
    log "Error: Script terminated due to Google Chat delivery failure."
    exit 1
elif [ "$sent_count" -gt 0 ]; then
    log "Success: Processed and sent $sent_count new logs to Google Chat."
    exit 0
else
    log "Success: No new logs sent."
    exit 0
fi