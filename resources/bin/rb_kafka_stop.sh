#!/bin/bash
exec 2>&1

PID=$(ps aux |grep java | grep kafka| grep server.properties | awk '{print $2}')
if [ "x$PID" != "x" ]; then
  logger -t svkill "kafka"
  kill -9 $PID
fi
