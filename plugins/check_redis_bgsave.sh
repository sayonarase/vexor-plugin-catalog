#!/bin/bash

# ========================================================================================
# Custom Nagios plugin to check Redis Bgsave
#
# Description   : Nagios Plugin to verify if 'Bgsave' was completed 
#                 within the given duration for one or more redis processes
#                 (queries the 'lastsave' timestamp)
#
# Usage         : ./check_redis_bgsave.sh
# ========================================================================================

NOT_RUN=0
REDIS_USER="redis"  # Specifty the user for redis processes
REDIS_CLI="/usr/bin/redis-cli"  # Specify the path to redis-cli
REDIS_CMD="lastsave"
BG_DURATION=7200   # in seconds
declare -a REDIS_PORTS=(7090 7091 7092)  # Add the redis ports for corresponding redis processes to monitor
REDIS_COUNT=$(ps u -u $REDIS_USER | grep redis-server | wc -l)
  
Check_Redis() {
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
    echo "WARNING Not able to Query Bgsave info for Redis-Processes: ${DOWN_PORTS[@]}"
    exit 1
fi
}
  
Check_Bgsave() {
for PORT1 in "${REDIS_PORTS[@]}"
    do
    BGSAVE_TIME=$($REDIS_CLI -p $PORT1 $REDIS_CMD)
    CURRENT_TIME=$(date '+%s')
    DIFFERENCE="$(($CURRENT_TIME - $BGSAVE_TIME))"
        if [ $DIFFERENCE -gt $BG_DURATION ]; then
            NOT_RUN=1
            DOWN_PORTSS+=("$PORT1")
        fi
    done
  
if [ $NOT_RUN == 1 ]; then
    echo "CRITICAL Bgsave not-running for more than $BG_DURATION seconds for Redis-processes: ${DOWN_PORTSS[@]}"
    exit 2
    elif [ $REDIS_COUNT -gt ${#REDIS_PORTS[@]} ]; then
        echo "WARNING Extra Redis-Processes running Current-count: $REDIS_COUNT Expected-Count: ${#REDIS_PORTS[@]}"
        exit 1
else
    echo "OK Redis Bgsave is Running, Redis-Processes Count: ${#REDIS_PORTS[@]}"
    exit 0
fi
}
  
Check_Redis
Check_Bgsave