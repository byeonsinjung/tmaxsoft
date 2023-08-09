#!/bin/bash

for i in {0..100}; do
	if jps -l | grep -q kafka.Kafka; then exit 0; fi
	sleep 0.1
done
