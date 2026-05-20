#!/bin/bash

# ========================================================================================
# Custom Nagios plugin to check Redis processes
#
# Description   : Nagios Plugin to verify if one or more given redis processes are running
#
# Usage         : ./check_redis_process.sh
# ========================================================================================
  
NOT_RUN=0
REDIS_USER="redis"  # Specifty the user for redis processes
declare -a REDIS_PORTS=(7090 7091 7092)  # Add the redis ports for corresponding redis processes to monitor
REDIS_COUNT=$(ps u -u $REDIS_USER | grep redis-server | wc -l)
  
for PORT in "${REDIS_PORTS[@]}"
    do
        ps u -u $REDIS_USER | grep redis-server | grep -q "$PORT"
        OUTPUT=$?
        if [ $OUTPUT == 1 ]; then
           NOT_RUN=1
           DOWN_PORTS+=("$PORT")
        fi
done
  
if [ $NOT_RUN == 1 ]; then
    echo "CRITICAL Redis-Processes not running are: ${DOWN_PORTS[@]}"
    exit 2
    elif [ $REDIS_COUNT -gt ${#REDIS_PORTS[@]} ]; then
        echo "WARNING Extra Redis-Processes running Current-count: $REDIS_COUNT Expected-Count: ${#REDIS_PORTS[@]}"
        exit 1
else
    echo "OK Number of Redis-Processes running are: ${#REDIS_PORTS[@]}"
    exit 0
fi