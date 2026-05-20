#!/bin/bash

AUTHOR="Jozef Rebjak"
VERSION="1.0"

# Plugin return codes
STATE_OK=0
STATE_CRITICAL=2
STATE_WARNING=1
STATE_UNKNOWN=3

if [[ -z "$1" ]] ; then
 echo $SCRIPTNAME Author: $AUTHOR version $VERSION
 echo ""
 echo "Missing parameter!"
 echo "Usage: ./check_ap_status.sh hostName"
 echo "This nagios plugins comes with ABSOLUTELY NO WARRANTY."
 exit $STATE_UNKNOWN
fi

# Variables
ENDPOINT="YOUR_ENDPOINT" # For example https://cloud-fra.aerohive.com
OWNER_ID="YOUR_OWNER_ID"
AUTH="Bearer YOUR_AUTH_TOKEN"
ID="YOUR_ID"
URI="YOUR_URI"
SECRET="YOUR_SECRET"

# API Call
CURL=$(curl --request GET \
     --silent ''"$ENDPOINT"'/xapi/v1/monitor/devices?ownerId='"$OWNER_ID"'' \
     --header 'Authorization: '"$AUTH"'' \
     --header 'X-AH-API-CLIENT-ID: '"$ID"'' \
     --header 'X-AH-API-CLIENT-REDIRECT-URI: '"$URI"'' \
     --header 'X-AH-API-CLIENT-SECRET: '"$SECRET"'')

# Get Model & Status
MODEL=`echo $CURL | jq '.data[] | select(.hostName=="'$1'")' | jq -r '.model'`
STATUS=`echo $CURL | jq '.data[] | select(.hostName=="'$1'")' | jq -r '.connected'`

# Get Uptime
CURRENT_TIME=`date +%s%3N`
SYSTEM_UPTIME=`echo $CURL | jq '.data[] | select(.hostName=="'$1'")' | jq -r '.systemUpTime'`
UPTIME=$(( $CURRENT_TIME - $SYSTEM_UPTIME ))
CONVERT=`echo "scale=2;${UPTIME}/1000" | bc` # Converting from milliseconds to seconds
seconds=`echo $CONVERT | awk '{printf("%d\n",$1 + 0.5)}'` # Rounding seconds
UPTIME_OUTPUT=`eval "echo $(date -ud "@$seconds" +'$((%s/3600/24)) days %H hours %M minutes %S seconds')"`

CHCK=`echo $STATUS`

if [[ "$CHCK" == "true" ]]; then
   CHECK="OK"
   STATUS_PERF=1
else
   CHECK="CRITICAL"
   STATUS_PERF=0
fi

perfData=$(echo $STATUS_PERF)

if [[ "$CHECK" == "OK" ]]; then
   echo "OK: $MODEL is connected to the Cloud. Uptime: $UPTIME_OUTPUT|Status=$perfData;;0;1;"
   exit $STATE_OK
elif [[ "$CHECK" == "CRITICAL" ]]; then
   echo "CRITICAL: $MODEL is not connected to the Cloud.|Status=$perfData;;0;1;"
   exit $STATE_CRITICAL
