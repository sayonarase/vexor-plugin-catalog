#!/usr/bin/python3
##Make sure your reference document is located in a directory called /ref, that lives at the same level as this script.
##In ./ref, there should be a reference file that matches the exact expected output of the command being ran. In this case, /usr/bin/beegfs-check-servers
import subprocess
import sys

# Nagios plugin return codes
OK = 0
WARNING = 1
CRITICAL = 2
UNKNOWN = 3

# Run the command and capture its output
try:
    output = subprocess.check_output(['/usr/bin/beegfs-check-servers'], stderr=subprocess.STDOUT)
except subprocess.CalledProcessError as e:
    print(f'ERROR: {e.output}', end='')
    sys.exit(UNKNOWN)

# Check the output against the reference file
try:
    with open('./ref/check-server-output', 'r') as f:
        ref_output = f.read()
except FileNotFoundError:
    print('ERROR: Reference file not found')
    sys.exit(UNKNOWN)

if output.decode() == ref_output:
    print(f'OK: Output matches reference file')
    sys.exit(OK)
else:
    print(f'CRITICAL: Output does not match reference file')
    sys.exit(CRITICAL)
