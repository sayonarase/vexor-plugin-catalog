#!/usr/bin/env python
# or !/usr/bin/env python3 depending on the version you have

from datetime import datetime
import subprocess
import sys

today = datetime.now()


def get_expiration_from_file(ksName,passphrase):
    with open(ksName) as c:
        try:
            # Command that is run here: keytool -list -v -keystore example.jks -storepass 12345678
            nextUpdate = subprocess.check_output(["/usr/bin/keytool", "-list", "-v","-keystore", ksName,"-storepass",passphrase], stderr=subprocess.STDOUT).decode('ascii')
            nextUpdate = nextUpdate.split("until: ")
            nextUpdate = nextUpdate[1:]
            
            results = []
            for cert in nextUpdate:
                cert = cert.split("\n")[0]
                # Data before splitting: 'Fri Sep 09 20:04:04 CEST 2022'
                exp_date = datetime.strptime(cert, "%a %b %d %H:%M:%S %Z %Y")
                results.append(is_expired(exp_date))
            return results
        except subprocess.CalledProcessError as e:
            print("Cert file with error")
            sys.exit(2)


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


if len(sys.argv) == 3:
    alerts = get_expiration_from_file(sys.argv[1],sys.argv[2])
    message = ""
    maxalert = 0
    for r in alerts:
        if r[0] is not 0:
            message += r[1]
            maxalert = max(maxalert, r[0])
    if maxalert == 0:
        print(("OK Certs expire in more than {0} days".format(60)))
        sys.exit(0)
    else:  
        print(message)
        sys.exit(maxalert)

else:
    # Correct calling is ./check_jks.py example.jks 12345678
    print("UNKNOWN Plugin was not called correctly")
    sys.exit(3)
