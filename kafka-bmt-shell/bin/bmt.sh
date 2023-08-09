#!/bin/bash

if [ -z $1 ]; then echo "Need config file."; exit 0; fi
if [ ! -f $1 ]; then echo "Can't find config file [ $1 ]."; exit 0; fi

CONF_FILE=$1
START_LINE_NUM=`grep -n "OPTIONS START" $CONF_FILE | cut -d: -f1`
END_LINE_NUM=`grep -n "OPTIONS END" $CONF_FILE | cut -d: -f1`
EXEC_SH=`grep BENCHMARK_SH $CONF_FILE | cut -d\" -f2`
EXEC_SH="$EXEC_SH `sed -n "$((START_LINE_NUM+1)),$((END_LINE_NUM-1))p" $CONF_FILE`"
RCOUNT=`grep RCOUNT $CONF_FILE | cut -d= -f2`
SERVER_HOST=`grep SERVER_HOST $CONF_FILE | cut -d= -f2`
SERVER_USERNAME=`grep SERVER_USERNAME $CONF_FILE | cut -d= -f2`
BOOT_SH=`grep BOOT_SH $CONF_FILE | cut -d= -f2`
DOWN_SH=`grep DOWN_SH $CONF_FILE | cut -d= -f2`
KAFKA_PORT=`grep KAFKA_PORT $CONF_FILE | cut -d= -f2`
METRIC_INTERVAL=`grep METRIC_INTERVAL $CONF_FILE | cut -d= -f2`
LOG_DIR=../logs/`basename $CONF_FILE | sed s/.conf//`-`date +%m%d-%H%M%S`

function kafka-boot-check(){
	ssh -T ${SERVER_USERNAME}@${SERVER_HOST} << EOF > tmp
jps -l
EOF

	if grep -q "kafka.Kafka" tmp; then echo true; else echo false; fi
	rm tmp
}

function kafka-boot(){
	echo "Boot Kafka."
	ssh -T ${SERVER_USERNAME}@${SERVER_HOST} << EOF > /dev/null
$BOOT_SH
bash wait-boot.sh; sleep 1
EOF

	echo "Check if kafka is booted."
	if ! `kafka-boot-check`; then echo "ERROR: Kafka not booted."; exit 0; fi

	echo "Run metric shell."	
	ssh -T ${SERVER_USERNAME}@${SERVER_HOST} << EOF > /dev/null &
nohup bash metric.sh ${SERVER_HOST}:${KAFKA_PORT} $METRIC_INTERVAL &
EOF
}

function kafka-perf(){
	$EXEC_SH | tee ${LOG_DIR}/perf-${i}.log
}

function kafka-down(){
	echo "Get the metric log."
	scp ${SERVER_USERNAME}@${SERVER_HOST}:metric.csv ${LOG_DIR}/metric-${i}.csv

	echo "Down kafka and clear kafka log."
	ssh -T ${SERVER_USERNAME}@${SERVER_HOST} << EOF > /dev/null
$DOWN_SH
bash wait-down.sh; sleep 1
rm -rf /tmp/kafka-logs
EOF
}

mkdir -p $LOG_DIR

for ((i=1 ; i <= $RCOUNT ; i++)); do
	echo "######## PERF $i ########"
	echo "#### BOOT ####"
        kafka-boot; echo "Kafka booted."; sleep 1
	echo "#### PERF ####"
	kafka-perf; sleep 1
	echo "#### DOWN ####"
        kafka-down; echo "Kafka downed."; sleep 1
done
