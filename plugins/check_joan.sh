#!/bin/sh
set -e

main() {
date=$(date -R)
auth=$(hmac_sha256 "$api_key" "$api_secret" "GET" "" "" "$date" "/api/device/")
o=$(curl --header "Authorization: $auth" --max-time 30 \
         --header "Date: $date" -s --connect-timeout 2 \
        $host/api/device/ | \
    jq -c '[.[]|{name:.Options.Name,uuid:.Uuid,state:.State,battery:.Status.Battery}]|.[]' | \
    awk -v u="$show_id" -v w="$warn" -v c="$crit" '
function cb(b) {
  if (0+b > 0+w) return 0;
  if (0+b > 0+c) return 1;
  return 2;
}
function cs(s) {
  if (s=="online")   { onl++; return 0; }
  if (s=="charging") { chg++; return 1; }
  if (s=="offline")  { ofl++; return 2; }
  unk++; return 3;
}
function max(a,b) {
  if (0+a>0+b) return a;
  return b;
}

BEGIN { ofl=0; onl=0; chg=0; unk=0; outp=""; dout=""; status="OK"; }
{

  match($0, /"name":"[^"]+"/); n=substr($0,RSTART+8,RLENGTH-9);
  if (u) {
    match($0, /"uuid":"[^"]+"/); u=substr($0,RSTART+8,RLENGTH-9);
    n= n " (" u ")";
  }
  match($0, /"state":"[^"]+"/); s=substr($0,RSTART+9,RLENGTH-10);
  match($0, /"battery":"[^"]+"/); b=substr($0,RSTART+11,RLENGTH-12);
  
  l=max(cb(b),cs(s));

  dout=sprintf("%s %c%s battery%c=%i%%;%i;%i",dout, 39, n, 39, b, w, c);
  if (0+l==3) {
    outp=sprintf("%s\nUNKNOWN - device %s is %s, battery at %i%%",outp,n,s,b);
    if (status!="CRITICAL") status="WARNING"
  } 
  if (0+l==2) {
    outp=sprintf("%s\nCRITICAL - device %s is %s, battery at %i%%",outp,n,s,b);
    status="CRITICAL";
  }
  if (0+l==1) {
    outp=sprintf("%s\nWARNING - device %s is %s, battery at %i%%",outp,n,s,b);
    if (status!="CRITICAL") status="WARNING"
  }

}
END { print status " - total " ofl+onl+chg+unk " devices (" \
       onl " online, "  chg " charging, " ofl " offline, " unk " unknown)" \
       outp " |" dout }'
)
echo "$o"
case ${o:0:1} in
 C) exit $STATE_CRITICAL;;
 W) exit $STATE_WARNING;;
 O) exit $STATE_OK;;
 *) exit $STATE_UNKNOWN;;
esac

}

get_args() {

for e in "curl" "openssl" "jq" "awk"; do
  which $e >/dev/null 2>&1 || { echo $e not found; exit $STATE_UNKNOWN; };
done

crit=5
warn=15
show_id=0
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
VERSION=0.01
PROGRAM=${0##*/}

while getopts ":c:w:H:k:s:u" opt; do
  case $opt in
    c) crit=$OPTARG;;
    w) warn=$OPTARG;;
    H) host=$OPTARG;;
    k) api_key=$OPTARG;;
    s) api_secret=$OPTARG;;
    u) show_id=1;;
    *) echo "invalid option"; show_help; exit $STATE_UNKNOWN;;
  esac
done

[ -z "$host" -o -z "$api_key" -o -z "$api_secret" ] && { show_help; exit $STATE_UNKNOWN; }
[ "${api_secret:0:5}" == "file:" ] && {
  api_secret=${api_secret:5}
  [ "${api_secret:0:1}" == "/" ] || api_secret="$OMD_ROOT/$api_secret"
  [ -f "$api_secret" ] || { echo "secret file $api_secret not found"; exit $STATE_UNKNOWN; }
  api_secret=$(cat $api_secret||{ echo "unable to read $api_secret";  exit $STATE_UNKNOWN; })
}

main
}

show_help() {
cat <<EOF

check_joan - v$VERSION

Usage: $PROGRAM -H http://joan_host:port -k api_key -s api_secret [-c <critical>] [-w <warning>] [-u]

Options:
 -H joan server url,
 -w battery warning level (default 15%),
 -c battery critical level (default 5%),
 -k api key,
 -s api secret,
    can have prefix "file:" followed by location of the file with the secret.
 -u show uuids in the output

Example:
  $PROGRAM -H http://joan.company.com:8081 -k d4508ad5491f14df -s file:etc/joan.secret
EOF
}

hmac_sha256() {
# $1 api key
# $2 api secret
# $3 http verb
# $4 Content-Sha256 (optional)
# $5 Content-Type (optional)
# $6 date
# $7 req path
printf "$1:$(printf "%s\n%s\n%s\n%s\n%s" "$3" "$4" "$5" "$6" "$7"|\
         openssl dgst -sha256 -hmac "$2" -binary | base64 -w 0)"
}

get_args "$@"
