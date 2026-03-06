#!/bin/bash
#######################################################################
# Kafka producer with file support and timestamp update
#######################################################################

# DEFAULTS
KAFKA_HOST="kafka.service:9092"
TOPIC=""
FILE=""
SLEEP_INTERVAL=1   # Default 1 second between lines

# FUNCTIONS
function usage() {
  echo "Usage: $0 -t <topic> [-f <file>] [-s <sleep_interval>] [-h]"
  echo "  -t <topic>          Kafka topic to produce to"
  echo "  -f <file>           File to read lines from (optional)"
  echo "  -s <sleep_interval> Seconds to wait between lines (default 1)"
  echo "  -h                  Show this help message"
  exit 1
}

# Function to send a line to Kafka
function send_line() {
  local line="$1"
  echo "$line" | /usr/bin/kafka-console-producer --broker-list "$KAFKA_HOST" --topic "$TOPIC" > /dev/null
}

# Update or add timestamp field to JSON
function update_timestamp() {
  local json="$1"
  local ts
  ts=$(date +%s)  # current timestamp in seconds
  # Use jq to set or update 'timestamp' field
  echo "$json" | jq -c --arg ts "$ts" '.timestamp = ($ts|tonumber)' # Remove -c if you get overwhelmed with the amount of data
}

# Parse options
while getopts "t:f:s:h" opt; do
  case $opt in
    t) TOPIC=$OPTARG ;;
    f) FILE=$OPTARG ;;
    s) SLEEP_INTERVAL=$OPTARG ;;
    h) usage ;;
    *) usage ;;
  esac
done

# VALIDATIONS:
# Check prerequisites
if [ ! -f /usr/bin/kafka-console-producer ]; then
  echo "Kafka producer not found on this node"
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo "jq command not found, please install it"
  exit 1
fi

if [ -z "$TOPIC" ]; then
  usage
fi

if [ -n "$FILE" ] && [ ! -f "$FILE" ]; then
  echo "File '$FILE' does not exist"
  exit 1
fi

# MAIN:
echo "Producing to topic '$TOPIC' on Kafka host $KAFKA_HOST ..."

# If file is provided, read line by line
if [ -n "$FILE" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    # Skip empty lines
    [ -z "$line" ] && continue

    # Update/add timestamp
    line_with_ts=$(update_timestamp "$line")

    # Send to Kafka
    send_line "$line_with_ts"

    # Sleep between lines
    sleep "$SLEEP_INTERVAL"
  done < "$FILE"

  echo "Finished producing all lines from $FILE"
  exit 0
else
  # Interactive mode
  /usr/bin/kafka-console-producer --broker-list "$KAFKA_HOST" --topic "$TOPIC"
fi