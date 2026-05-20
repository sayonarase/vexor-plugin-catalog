#!/usr/bin/python

import os
os.chdir('/tmp')
#sapnwrfc - A Python interface to SAP NetWeaver R/3 systems using the RFC protocol
#SAP RFC Connector using the SAP NW RFC SDK for Python http://www.piersharding.com/blog/
#https://github.com/piersharding/python-sapnwrfc
import sapnwrfc
import sys
import json


if len(sys.argv) <> 4:
	print "Usage:" + sys.argv[0] +" <SID> <warning shortdumps> <critical shortdumps>"
  	sys.exit(3)
  
from datetime import date, timedelta
yesterday = date.today() - timedelta(1)
if os.path.exists("/etc/sapmon/"+sys.argv[1]+".yml"):   
	sapnwrfc.base.config_location = "/etc/sapmon/"+sys.argv[1]+".yml"
else:
	print "File not found:" +"/etc/sapmon/"+sys.argv[1]+".yml"
  	sys.exit(3)
sapnwrfc.base.load_config()
 
#print "making a new connection:"
try:
        conn = sapnwrfc.base.rfc_connect()
        fd = conn.discover("/SDF/GET_DUMP_LOG")
        f = fd.create_function_call()
        f.DATE_FROM(yesterday.strftime('%Y%m%d'))
        f.invoke()

        d = f.ET_E2E_LOG.value
        todo = {'results': d}
	st22= str(len(d))
	if len(d) >= int(sys.argv[3]):
		print "CRITICAL: ShortDumps in last two days -w "+sys.argv[2] +" -c "+sys.argv[3]+": "+st22+" | ShortDump="+st22
		sys.exit(2)
	elif len(d) >= int(sys.argv[2]):
		print "WARNING: ShortDumps in last two days -w "+sys.argv[2] +" -c "+sys.argv[3]+": "+st22+" | ShortDump="+st22
		sys.exit(1)
	else:
		print ('OK: ShortDumps in last two days -w '+sys.argv[2] +' -c '+sys.argv[3]+': '+st22+' | ShortDump='+st22)
		sys.exit(0)

	conn.close()


except sapnwrfc.RFCCommunicationError as e:
	if 'NO_DATA_FOUND' in e[0]:
		print "OK: ShortDumps in last two days -w "+sys.argv[2] +" -c "+sys.argv[3]+": 0 | ShortDump=0"
	else:
        	print "UKNOWN:" + e[0]
		sys.exit(3)
		
