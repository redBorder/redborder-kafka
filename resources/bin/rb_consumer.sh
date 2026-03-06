#!/bin/bash
#######################################################################    
# Copyright (c) 2014 ENEO Tecnología S.L.
# This file is part of redBorder.
# redBorder is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# redBorder is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License License for more details.
# You should have received a copy of the GNU Affero General Public License License
# along with redBorder. If not, see <http://www.gnu.org/licenses/>.
#######################################################################

TOPIC=""
KAFKA_HOST="kafka.service:9092"
BEGIN=0
COUNT=0
KEY=0
FILEPATH=""
TIMEOUT=0   # in seconds

function usage() {
cat <<EOF

Kafka Topic Consumer

Usage:
  $0 -t <topic> [options]

Required:
  -t <topic>              Kafka topic to consume
WARNING: If topic doesn't exist, this script will create it. Please run rb_get_topics if unsure.

Options:
  -b                      Read messages from beginning of topic
  -k                      Print message keys
  -c <count>              Stop after consuming N messages
  -s <seconds>            Run consumer for N seconds (hard runtime limit)
  -f <file_path>          Save consumed events to file
  -h, --help              Show this help message

Examples:
  Consume topic:
    $0 -t sflow

  Consume from beginning:
    $0 -t rb -b

  Consume 100 messages:
    $0 -t orders -c 100

  Run consumer for 30 seconds:
    $0 -t orders -s 30

  Save events to file:
    $0 -t orders -f events.log

  Read from beginning and store output:
    $0 -t orders -b -f events.log

EOF
exit 0
}

# Support long option --help
for arg in "$@"; do
  if [ "$arg" == "--help" ]; then
    usage
  fi
done

# Parse options
while getopts "kbt:c:s:f:h" name; do
  case $name in
    k) KEY=1;;
    b) BEGIN=1;;
    t) TOPIC="$OPTARG";;
    c) COUNT="$OPTARG";;
    s) TIMEOUT="$OPTARG";;
    f) FILEPATH="$OPTARG";;
    h) usage;;
    *) usage;;
  esac
done

# Validatations
if [ ! -x /usr/bin/kafka-console-consumer ]; then
  echo "kafka-console-consumer not installed on this node"
  exit 1
fi

if [ -z "$TOPIC" ]; then
  usage
fi

if [ "$TIMEOUT" -lt 0 ]; then
  echo "Define valid timeout"
  exit 1
fi

echo "Waiting for $TOPIC data (kafka: $KAFKA_HOST) ..."

# Build options
options=""
[ "$COUNT" -gt 0 ] && options="$options --max-messages $COUNT"
[ "$KEY" -eq 1 ] && options="$options --property print.key=true"
[ "$BEGIN" -eq 1 ] && options="$options --from-beginning"

# Build base command
cmd=(timeout "$TIMEOUT"s /usr/bin/kafka-console-consumer --bootstrap-server "$KAFKA_HOST" --topic "$TOPIC" $options)

# Run command with optional tee
if [ -n "$FILEPATH" ]; then
  "${cmd[@]}" | tee -a "$FILEPATH"
  RET=${PIPESTATUS[0]}
else
  "${cmd[@]}"
  RET=$?
fi

exit $RET