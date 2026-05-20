#!/usr/bin/env python
# or !/usr/bin/env python3 depending on the version you have

from datetime import datetime
import subprocess
import sys

today = datetime.now()


def get_expiration_from_file(crlName):
    with open(crlName) as crl:
        try:
            if "BEGIN X509 CRL" in crl.read():
                format = "PEM"
        except UnicodeDecodeError as e:  # trying to read DER format will throw this error, not fancy but effective
            format = "DER"
        try:
            nextUpdate = subprocess.check_output(["/usr/bin/openssl", "crl", "-inform", format,
                                                  "-noout", "-nextupdate", "-in", crlName], stderr=subprocess.STDOUT).decode('ascii')
            # Data before splitting: 'nextUpdate=Oct 28 04:57:01 2020 GMT\n'
            nextUpdate = nextUpdate.split("=")[1][:-1]
            exp_date = datetime.strptime(nextUpdate, "%b %d %H:%M:%S %Y %Z")

            return is_expired(exp_date)
        except subprocess.CalledProcessError as e:
            print("Crl file with error")
            sys.exit(2)


def is_expired(exp):
    days_to_exp = (exp-today).days
    if days_to_exp <= 3:
        print("CRITICAL CRL about to expire or already expired, run for your lives! : {0} days to expiration".format(
            days_to_exp))
        exitcode = 2
    elif days_to_exp < 15:
        print("CRITICAL CRL expiration in less than 15 days: {0} days to expiration".format(
            days_to_exp))
        exitcode = 2
    elif days_to_exp < 30:
        print("WARNING CRL expiration in less than 30 days: {0} days to expiration".format(
            days_to_exp))
        exitcode = 1
    else:
        print("OK CRL expires in : {0} days to expiration".format(days_to_exp))
        exitcode = 0

    sys.exit(exitcode)


if len(sys.argv) == 2:
    get_expiration_from_file(sys.argv[1])
else:
    print("UNKNOWN Plugin was not called correctly")
    sys.exit(3)

#exp = get_expiration_from_file('testcrl.crl')
#print("Crl expiraton: ", exp)
# is_expired(exp)
