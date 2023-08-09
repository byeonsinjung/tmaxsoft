#!/bin/bash

KAFKA_ADDRESS=$1
METRIC_INTERVAL=$2
KAFKA_PID=`jps -l | grep kafka.Kafka | cut -d' ' -f1`

echo "time,cpu,mem,rq,sq" > metric.csv

while jps -l | grep -q kafka.Kafka; do
	CPU=`top -b -n 1 -p $KAFKA_PID | tail -1 | awk '{print $9}'`

	if [ "$CPU" != "0.0" ]; then
		MEM=`jstat -gc $KAFKA_PID | tail -1 | awk '{print ($3 + $4 + $6 + $8) / ($1 + $2 + $5 + $7) * 100}'`
		RQ=`netstat -ant | awk '{print $2, $4}' | grep $KAFKA_ADDRESS | awk '{i += $1} END {print i}'` 
		SQ=`netstat -ant | awk '{print $3, $4}' | grep $KAFKA_ADDRESS | awk '{i += $1} END {print i}'`

		#printf "%-11s CPU=%-6s MEM=%-8s RQ=%-6s SQ=%s\n" `date +%H:%M:%S.%1N` $CPU $MEM $RQ $SQ >> metric.log # pretty view
		echo `date +%H:%M:%S.%1N`,${CPU},${MEM},${RQ},${SQ} >> metric.csv # csv
	fi

	sleep $METRIC_INTERVAL;
done

rm -rf metric.csv
