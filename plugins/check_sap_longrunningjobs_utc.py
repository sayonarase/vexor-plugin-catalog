#!/usr/bin/python

import sys
if len(sys.argv) <> 3:
	print "Usage:" + sys.argv[0] +" <SID>" +" <seconds>"
  	sys.exit(3)

import os
os.chdir('/tmp')
#sapnwrfc - A Python interface to SAP NetWeaver R/3 systems using the RFC protocol
#SAP RFC Connector using the SAP NW RFC SDK for Python http://www.piersharding.com/blog/
#https://github.com/piersharding/python-sapnwrfc
import sapnwrfc
import json
import datetime
start = datetime.datetime.now()  
#start = datetime.datetime.utcnow()  
from datetime import date, timedelta
from datetime import datetime
import time
today = date.today()
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
        fd = conn.discover("RFC_READ_TABLE")
        f = fd.create_function_call()
        f.QUERY_TABLE("TBTCO")
        f.DELIMITER(";")
        f.ROWCOUNT(50)
	f.OPTIONS( [{ 'TEXT': " STATUS = 'R' "}] )
	f.FIELDS( [ {'FIELDNAME' : 'JOBNAME'},{'FIELDNAME' : 'SDLSTRTDT'},{'FIELDNAME' : 'SDLSTRTTM'},{'FIELDNAME' : 'SDLUNAME'},{'FIELDNAME' : 'STATUS'},{'FIELDNAME' : 'WPPROCID'},{'FIELDNAME' : 'BTCSYSREAX'} ] )
        f.invoke()

        d = f.DATA.value
        todo = {'results': d}
	number=0
	number1=0
	for i in d:
		i_split =  i['WA'].split(';')
		s = i_split[1].strip() + " " + i_split[2].strip()
		d1 = datetime.strptime(s, "%Y%m%d %H%M%S")
		b = datetime.utcnow()
		c = b - d1
		if c > timedelta(seconds=int(sys.argv[2])):
			number += 1
	
	#print number
	lock = str(number)
	if number  >= 1:
		print "CRITICAL - " + str(number) + " Jobs running over "+sys.argv[2]+" seconds | jobs="+str(number)
		sys.exit(2)
	else:
		print "OK - No Jobs running over "+sys.argv[2]+" seconds | jobs="+str(number)
		sys.exit(0)


	conn.close()
	#print "closing..."

except sapnwrfc.RFCCommunicationError as e:
	if 'NO_DATA_FOUND' in e[0]:
		print "OK - LockTable over 1 days: "+lock+" LockTable | LockTable="+lock
	else:
        	print "UKNOWN:" + e[0]
		sys.exit(3)
		
