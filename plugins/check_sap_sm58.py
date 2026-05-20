#!/usr/bin/env python

import os
os.chdir('/tmp')

#sapnwrfc - A Python interface to SAP NetWeaver R/3 systems using the RFC protocol
#SAP RFC Connector using the SAP NW RFC SDK for Python http://www.piersharding.com/blog/
#https://github.com/piersharding/python-sapnwrfc
import sapnwrfc
import sys
import json

if len(sys.argv) <> 2:
        print "Usage:" + sys.argv[0] +" <SID>"
        sys.exit(3)


if os.path.exists("/etc/sapmon/"+sys.argv[1]+".yml"):
        sapnwrfc.base.config_location = "/etc/sapmon/"+sys.argv[1]+".yml"
else:
        print "File not found:" +"/etc/sapmon/"+sys.argv[1]+".yml"
        sys.exit(3)
sapnwrfc.base.load_config()


from datetime import date, timedelta
today = date.today()
 
w = " ARFCSTATE = 'SYSFAIL' AND  ARFCDATUM = '" + today.strftime('%Y%m%d') + "' " 

di = { 'TEXT': w }

#print "making a new connection:"
try:
        conn = sapnwrfc.base.rfc_connect()
        fd = conn.discover("RFC_READ_TABLE")
        f = fd.create_function_call()
        f.QUERY_TABLE("ARFCSSTATE")
        f.DELIMITER(";")
        f.ROWCOUNT(5000)
        f.OPTIONS( [ di ] )
	f.FIELDS( [ {'FIELDNAME' : 'ARFCUSER'},{'FIELDNAME' : 'ARFCFNAM'},{'FIELDNAME' : 'ARFCDEST'},{'FIELDNAME' : 'ARFCDATUM'},{'FIELDNAME' : 'ARFCUZEIT'},{'FIELDNAME' : 'ARFCMSG'},{'FIELDNAME' : 'ARFCTCODE'} ] )
        f.invoke()

        d = f.DATA.value
        todo = {'results': d}
        
	number=0
        for i in d:
                        number += 1
 	#print number		
	
	if number <> 0:
        	for i in d:
                        i_split =  i['WA'].split(';')
                        print  i_split[0].strip() + ';'+ i_split[2].strip() + ';' 
                        number += 1
        conn.close()
#	print "closing..."

except sapnwrfc.RFCCommunicationError:
	print "bang!"
        if 'NO_DATA_FOUND' in e[0]:
                print "No data."
        else:
                print "UKNOWN:" + e[0]
                sys.exit(3)


