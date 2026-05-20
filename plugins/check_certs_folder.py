#!/usr/bin/env python3
# or !/usr/bin/env python3 depending on the version you have

from datetime import datetime
import subprocess
import sys
import os
import glob

today = datetime.now()


def get_expiration_from_file(certName):
    with open(certName) as c:
        try:
            format = "PEM"
            c.read()
        except UnicodeDecodeError as e:  # trying to read DER format will throw this error, not fancy but effective
            format = "DER"
        try:
            nextUpdate = subprocess.check_output(["/usr/bin/openssl", "x509", "-in", certName,
                                                  "-inform", format, "-enddate", "-noout"], stderr=subprocess.STDOUT).decode('ascii')
            # Data before splitting: 'nextUpdate=Oct 28 04:57:01 2020 GMT\n'
            nextUpdate = nextUpdate.split("=")[1][:-1]
            exp_date = datetime.strptime(nextUpdate, "%b %d %H:%M:%S %Y %Z")
            return is_expired(exp_date)
        except subprocess.CalledProcessError as e:
            print("Certificate file with error")
            return [0]


def is_expired(exp):
    days_to_exp = (exp-today).days
    if days_to_exp <= 15:
        r = [2, ("CRITICAL Cert about to expire or already expired, run for your lives! : {0} days to expiration".format(
            days_to_exp))]
    elif days_to_exp < 30:
        r = [2, ("CRITICAL Cert expiration in less than 30 days: {0} days to expiration".format(
            days_to_exp))]
    elif days_to_exp < 60:
        r = [1, ("WARNING Cert expiration in less than 60 days: {0} days to expiration".format(
            days_to_exp))]
    else:
        r = [
            0, ("OK Cert expires in : {0} days to expiration".format(days_to_exp))]
    return r


if len(sys.argv) == 2:
    all_f = os.listdir(sys.argv[1])
    alerts = ""
    maxalert = 0
    for f in all_f:
        if f[-4:]in ['.cer', '.pem', '.der', '.crt']:
            r = get_expiration_from_file(f)
            if r[0] is not 0:
                alerts += f + " " + r[1]
                maxalerts = max(maxalert, r[0])
    if maxalert == 0:
        print(("OK Certs expire in more than {0} days".format(60)))
        sys.exit(0)
    else:
        print(alerts)
        sys.exit(maxalert)


else:
    # Correct calling is ./check_cert_folder.py path/to/folder/
    print("UNKNOWN Plugin was not called correctly")
    sys.exit(3)
