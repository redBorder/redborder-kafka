#!/bin/bash

source /etc/sysconfig/kafka
exec /usr/bin/kafka-run-class -name kafkaServer -loggc kafka.Kafka /etc/kafka/server.properties
