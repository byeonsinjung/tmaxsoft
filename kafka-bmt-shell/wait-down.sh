#!/bin/bash

while jps -l | grep -q kafka.Kafka; do sleep 0.1; done
