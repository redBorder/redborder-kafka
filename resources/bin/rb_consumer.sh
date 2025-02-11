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

TOPIC="$1"
ZK_HOST="zookeeper.service"
BEGIN=0
COUNT=0
MAXTIME=0
KEY=0

function usage() {
  echo "Usage: $0 [-t <topic>] [-h] [-b] [-c <count>] [-k] [-m <timeout>] [-s <timestamp>]"
  echo
  echo "Options:"
  echo "  -t <topic>    Specify the Kafka topic to consume messages from (required)."
  echo "  -h            Display this help message."
  echo "  -b            Start consuming messages from the beginning of the topic."
  echo "  -c <count>    Limit the number of messages to consume."
  echo "  -k            Print the message keys along with their values."
  echo "  -m <timeout>  Set a consumer timeout in seconds. ERROR: This option is not supported by this script."
  echo "  -s <timestamp> Start consuming messages from a specific timestamp (epoch in s)."
  echo
  echo "Examples:"
  echo "  $0 -t my-topic                # Consume messages from 'my-topic'"
  echo "  $0 -t my-topic -b             # Start consuming from the beginning of 'my-topic'"
  echo "  $0 -t my-topic -c 10          # Consume up to 10 messages from 'my-topic'"
  echo "  $0 -t my-topic -m 5000        # Stop consuming after 5 seconds (5000 ms)"
  echo "  $0 -t my-topic -b -k          # Start from the beginning and print message keys"
  echo "  $0 -t my-topic -c 5 -m 10000  # Consume up to 5 messages or stop after 10 seconds"
  exit 1
}

while getopts "kbt:hc:m:" name; do
  case $name in
    k) KEY=1;;
    b) BEGIN=1;;
    t) TOPIC=$OPTARG;;
    c) COUNT=$OPTARG;;
    m) MAXTIME=$OPTARG;;
    h) usage;;
  esac
done

if [ ! -f /usr/bin/kafka-console-consumer ]; then
  echo "kafka not installed in this node"
  exit 0
fi

if [ "x$TOPIC" == "x" ]; then
  usage
else
  echo "Waiting $TOPIC data (zookeeper: $ZK_HOST) ..."

  options=""

  [ $COUNT -gt 0 ] && options="$options --max-messages $COUNT" 
  [ $MAXTIME -gt 0 ] && options="$options --consumer-timeout-ms $MAXTIME" 

  if [ $BEGIN -eq 1 ]; then
    if [ $KEY -eq 1 ]; then
      /usr/bin/kafka-console-consumer --zookeeper $ZK_HOST --topic "$TOPIC" --from-beginning $options --property print.key=true
      RET=$?
    else
      /usr/bin/kafka-console-consumer --zookeeper $ZK_HOST --topic "$TOPIC" --from-beginning $options
      RET=$?
    fi
  else
    if [ $KEY -eq 1 ]; then
      /usr/bin/kafka-console-consumer --zookeeper $ZK_HOST --topic "$TOPIC" $options --property print.key=true
      RET=$?
    else
      /usr/bin/kafka-console-consumer --zookeeper $ZK_HOST --topic "$TOPIC" $options
      RET=$?
    fi
  fi
fi
