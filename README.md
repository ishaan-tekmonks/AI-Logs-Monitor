# AI Logs Monitor

AI Query Monitor is a lightweight shell-based monitoring utility that extracts user queries from application logs and forwards them to Google Chat or local audit logs.

## Features

* Extracts:

  * Timestamp
  * User ID
  * Application ID
  * User Query
* Duplicate message prevention using SHA256 hashes
* Google Chat integration via Webhooks
* Local message logging when webhook is not configured
* Configurable processing time window
* Audit logging
* Cron-friendly execution


## Installation

Clone repository:

```bash
git clone https://github.com/ishaan-tekmonks/AI-Logs-Monitor

cd ai-logs-monitor
```

Create configuration:

```bash
cp config.env.sample config.env
```

Update configuration values.

## Configuration

Example:

```bash
LOG_FILE="/var/log/server.log.ndjson"

GOOGLE_CHAT_WEBHOOK=""

ENABLE_TIME_WINDOW=false

START_TIME="09:00"
END_TIME="17:00"

STATE_FILE="./processed_hashes.txt"
APP_LOG="./monitor.log"
MESSAGE_LOG="./messages.log"
```

### Configuration Parameters

| Variable            | Description                      |
| ------------------- | -------------------------------- |
| LOG_FILE            | Source log file                  |
| GOOGLE_CHAT_WEBHOOK | Google Chat Incoming Webhook URL |
| ENABLE_TIME_WINDOW  | Enable/Disable processing window |
| START_TIME          | Window start time                |
| END_TIME            | Window end time                  |
| STATE_FILE          | Duplicate tracking hashes        |
| APP_LOG             | Script audit log                 |
| MESSAGE_LOG         | Local message archive            |

## Running

Execute manually:

```bash
chmod +x monitor.sh

./monitor.sh
```

## Cron Example

Run every minute:

```bash
* * * * * /opt/ai-query-monitor/monitor.sh
```

## Duplicate Prevention

Each processed entry generates a SHA256 hash using:

```text
timestamp|userid|appid|question
```

Previously processed hashes are stored in:

```text
processed_hashes.txt
```

This prevents duplicate Google Chat notifications.

## Google Chat Integration

Configure:

```bash
GOOGLE_CHAT_WEBHOOK="https://chat.googleapis.com/..."
```

When configured, messages are posted directly to Google Chat.

If omitted, messages are written to:

```text
messages.log
```

## Example Output

```text
[thaidoclaw]

Time: 2026:06:09:11:47:07
User: user@tekmonks.com

Question:
This is a dummy question
```
