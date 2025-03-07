#!/usr/bin/env bash
# very simple script to send notifications to Gotify. Was written to work with Nagios.
# gotify.sh servername.xyz apitoken SERVICE/HOST message

GOTIFY_SERVER_URL="$1"
APITOKEN="$2"
TYPE=$3
MESSAGE="$4"

if [[ $# -lt 4 ]]; then
    echo "Missing arguments."
    exit 1
fi

# title will contain NAGIOS ALERT: and then the value of $NOTIFICATIONTYPE$ which is RECOVERY, CRITICAL, etc.

curl "https://$GOTIFY_SERVER_URL/message?token=$APITOKEN" -F "title=NAGIOS ALERT: $TYPE" -F "message=$MESSAGE" -F "priority=5" >/dev/null 2>&1 
