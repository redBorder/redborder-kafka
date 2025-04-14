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
KAFKA_HOST="kafka.service:9092"
BEGIN=0
COUNT=0
MAXTIME=0
KEY=0

function usage() {
    echo "$0 [-t <topic>][-h][-b][-c][-k][-m]"
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
    echo "Waiting $TOPIC data (kafka: $KAFKA_HOST) ..."

    options=""

    [ $COUNT -gt 0 ] && options="$options --max-messages $COUNT" 
    [ $MAXTIME -gt 0 ] && options="$options --consumer-timeout-ms $MAXTIME" 

    if [ $BEGIN -eq 1 ]; then
      if [ $KEY -eq 1 ]; then
         /usr/bin/kafka-console-consumer --bootstrap-server $KAFKA_HOST --topic "$TOPIC" --from-beginning $options --property print.key=true
         RET=$?
      else
         /usr/bin/kafka-console-consumer --bootstrap-server $KAFKA_HOST --topic "$TOPIC" --from-beginning $options
         RET=$?
      fi
    else
      if [ $KEY -eq 1 ]; then
         /usr/bin/kafka-console-consumer --bootstrap-server $KAFKA_HOST --topic "$TOPIC" $options --property print.key=true
         RET=$?
      else
         /usr/bin/kafka-console-consumer --bootstrap-server $KAFKA_HOST --topic "$TOPIC" $options
         RET=$?
      fi
    fi
fi
