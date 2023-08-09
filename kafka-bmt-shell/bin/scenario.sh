#!/bin/bash

if [ -z $1 ]; then echo "Need config file."; exit 0; fi
if [ ! -f $1 ]; then echo "Can't find scenario file [ $1 ]."; exit 0; fi

SCENARIO_FILE=$1

while IFS= read -r line; do
	echo "################ TEST [ $line ] ################"
	bash bmt.sh ../config/${line}.conf
	sleep 1
done < $SCENARIO_FILE
