#!/bin/bash
#######################################################################    
# Copyright (c) 2024 ENEO Tecnología S.L.
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

source $RBLIB/rb_manager_functions.sh
ZK_HOST="zookeeper.service"

TOPICS="$*"

if [ "x$TOPICS" == "x" ]; then
    for c in $(/usr/lib/redborder/scripts/rb_get_consumer_groups.rb 2>/dev/null); do 
        [ "x$BOOTUP" != "xnone" ] && set_color cyan
        echo "##############################################" 
        echo -n "   Consumer Group: "
        [ "x$BOOTUP" != "xnone" ] && set_color green
        echo "$c"
        [ "x$BOOTUP" != "xnone" ] && set_color cyan
        echo "##############################################" 
        [ "x$BOOTUP" != "xnone" ] && set_color norm
         /usr/bin/kafka-run-class kafka.tools.ConsumerOffsetChecker --zookeeper $ZK_HOST --group $c | sed 's/^Group[ \t]*//' | sed "s/^$c[ \t]*//"
        echo
    done
else
    for n in $TOPICS; do
        /usr/bin/kafka-run-class kafka.tools.ConsumerOffsetChecker --zookeeper $ZK_HOST --topic $n --group rb-group
    done
fi
