#!/usr/bin/env python3
import argparse
import subprocess

#This is to be ran over NRPE, with a service account on the distant end. 
#Exit Strings for informative output to Nagios/LibreNMS
OK_STR = "The RAID is OK!"
WARN_STR = "Warning! The RAID is Degraded!"
CRIT_STR = "Critical! The RAID has FAILED!"
UNK_STR = "Uh OH! Script is broken!"

parser = argparse.ArgumentParser(description='Python script to check RAID status')
parser.add_argument('-n', '--hostname', help='Hostname of the server', required=True)
args = parser.parse_args()

#In order for this to work, you will need a service account with permission to run this command.
#I do not recommend giving root permissions to a service account. 
#Instead, use visudo and provide the service account with permissions to run $command as root, and nothing else.


command = f"sudo /opt/MegaRAID/MegaCli/MegaCli64 -ShowSummary -a0"
output = subprocess.check_output(f"{command}", shell=True).decode()

if 'Degraded' in output:
    print(WARN_STR)
    exit(1)
elif 'Failed' in output:
    print(CRIT_STR)
    exit(2)
elif 'Online' in output:
    print(OK_STR)
    exit(0)
else:
    print(UNK_STR)
    exit(3)
