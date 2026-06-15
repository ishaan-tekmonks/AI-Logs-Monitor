#!/bin/bash

set -euo pipefail

source ./config.env

touch "$STATE_FILE"
touch "$APP_LOG"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$APP_LOG"
}

within_time_window() {

    local log_time="$1"

    if [ "$ENABLE_TIME_WINDOW" != "true" ]; then
        return 0
    fi

    if [[ "$log_time" < "$START_TIME" || "$log_time" > "$END_TIME" ]]; then
        return 1
    fi

    return 0
}

send_to_google_chat() {

    local timestamp="$1"
    local userid="$2"
    local appid="$3"
    local question="$4"

    local message="[${appid}]
        Time: ${timestamp}
        User: ${userid}

        Question:
        ${question}
    "

    if [ -z "${GOOGLE_CHAT_WEBHOOK:-}" ]; then

        { 
            echo "==================================================" 
            echo "$(date '+%Y-%m-%d %H:%M:%S')" 
            echo "[MESSAGE LOGGED TO LOCAL FILE ONLY]" 
            echo 
            echo "$message" 
        } >> "$MESSAGE_LOG"

        return 0
    fi

    payload=$(printf '{"text":"%s"}' \
        "$(echo "$message" | sed ':a;N;$!ba;s/\n/\\n/g')")

    if curl -s \
    --fail \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "$GOOGLE_CHAT_WEBHOOK" >/dev/null
    then

        {
            echo "=================================================="
            echo "$(date '+%Y-%m-%d %H:%M:%S')"
            echo "[MESSAGE SENT TO GOOGLE CHAT]"
            echo
            echo "$message"
        } >> "$MESSAGE_LOG"

        return 0
    fi

    {
        echo "=================================================="
        echo "$(date '+%Y-%m-%d %H:%M:%S')"
        echo "[GOOGLE CHAT DELIVERY FAILED]"
        echo
        echo "$message"
    } >> "$MESSAGE_LOG"

    return 1
}



grep "<MONITOR>" "$LOG_FILE" | while read -r line
do

```
timestamp=$(echo "$line" | grep -oP '"ts":"\K[^"]+')

log_time=$(echo "$timestamp" | cut -d':' -f4,5)

if ! within_time_window "$log_time"; then
    continue
fi

userid=$(echo "$line" | sed -n 's/.*<id>\(.*\)<\/id>.*/\1/p')

question=$(echo "$line" | sed -n 's/.*<question>\(.*\)<\/question>.*/\1/p')

appid=$(echo "$line" | sed -n 's/.*<aiappid>\(.*\)<\/aiappid>.*/\1/p')

[ -z "$userid" ] && continue
[ -z "$question" ] && continue
[ -z "$appid" ] && continue

hash=$(printf "%s|%s|%s|%s" \
    "$timestamp" \
    "$userid" \
    "$appid" \
    "$question" | sha256sum | awk '{print $1}')

if grep -q "^${hash}$" "$STATE_FILE"; then
    continue
fi

if send_to_google_chat "$timestamp" "$userid" "$appid" "$question"; then
    echo "$hash" >> "$STATE_FILE"
    log "Sent message user=$userid app=$appid"
else
    log "Failed to send message user=$userid app=$appid"
fi
```

done
