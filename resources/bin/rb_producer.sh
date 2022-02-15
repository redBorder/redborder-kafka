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
ZK_HOST="kafka.service:9092"

function usage() {
    echo "$0 [-t <topic>][-h]"
    exit 1
}

while getopts "t:h" name; do
  case $name in
    t) TOPIC=$OPTARG;;
    h) usage;;
  esac
done

if [ ! -f /usr/bin/kafka-console-producer ]; then
  echo "kafka not installed in this node"
  exit 0
fi

if [ "x$TOPIC" == "x" ]; then
    usage
else
    echo "Producing $TOPIC data (brokers: $brokerlist) ..."
    /usr/bin/kafka-console-producer --broker-list $ZK_HOST --topic $TOPIC
fi

