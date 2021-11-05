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

TOPICS="$*"
ZK_HOST="zookeeper.service"

if [ ! -f /usr/bin/kafka-topics ]; then
  echo "kafka not installed in this node"
  exit 0
fi

if [ "x$TOPICS" == "x" ]; then
  echo "you need to specify at least one topic to be deleted"
  echo "$0 <topic> [<topic>]"
  exit 0
fi


echo -n "Are you sure you want to delete the topics \"`echo $TOPICS | tr ' ' ','`\" on $ZK_HOST? (y/N) "
read VAR

if [ "x$VAR" == "xY" -o "x$VAR" == "xy" ]; then
    OIFS=$IFS
    IFS=','
    echo "Trying with zookeeper $ZK_HOST ..."
    IFS=' '
    RET=0
    for topic in $TOPICS; do        
      if [ $RET -eq 0 ]; then
        /usr/bin/kafka-topics --zookeeper "$ZK_HOST" --delete --topic $topic 
        RET=$?
      fi
 
      if [ $RET -eq 0 ]; then
          echo "  * topic: \"$topic\" deleted successfully"
      else
          echo "ERROR: topic: \"$topic\" cannot be deleted"
      fi
    done

    IFS=','
    IFS=$OIFS
fi

