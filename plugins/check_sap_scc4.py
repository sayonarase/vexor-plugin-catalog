#!/usr/bin/env python

import os
os.chdir('/tmp')

# enable debugging
import cgitb
cgitb.enable()

#sapnwrfc - A Python interface to SAP NetWeaver R/3 systems using the RFC protocol
#SAP RFC Connector using the SAP NW RFC SDK for Python http://www.piersharding.com/blog/
#https://github.com/piersharding/python-sapnwrfc
import sapnwrfc
import sys
import json
import cgi
form = cgi.FieldStorage()

if len(sys.argv) <> 5:
        print "Usage:" + sys.argv[0] +" <SID> <client> <settings eg: P23XX> <warning|critical>"
        sys.exit(3)

if os.path.exists("/etc/sapmon/"+sys.argv[1]+".yml"):
        sapnwrfc.base.config_location = "/etc/sapmon/"+sys.argv[1]+".yml"
else:
        print "File not found:" +"/etc/sapmon/"+sys.argv[1]+".yml"
        sys.exit(3)
sapnwrfc.base.load_config()

w = " MANDT = '"+sys.argv[2]+"' " 
di = { 'TEXT': w }

try:
        conn = sapnwrfc.base.rfc_connect()
        fd = conn.discover("RFC_READ_TABLE")
        f = fd.create_function_call()
        f.QUERY_TABLE("T000")
        f.DELIMITER(";")
        f.ROWCOUNT(50)
        f.OPTIONS( [ di ] )
	f.FIELDS( [ {'FIELDNAME' : 'MANDT'},{'FIELDNAME' : 'MTEXT'},{'FIELDNAME' : 'CCCATEGORY'},{'FIELDNAME' : 'CCCORACTIV'},{'FIELDNAME' : 'CCNOCLIIND'},{'FIELDNAME' : 'CCCOPYLOCK'},{'FIELDNAME' : 'CCIMAILDIS'},{'FIELDNAME' : 'CHANGEUSER'} ,{'FIELDNAME' : 'CHANGEDATE'} ] )
        f.invoke()

        d = f.DATA.value
        todo = {'results': d}
        
	scc4=""
	number=0
        for i in d:
                        number += 1
 	#print number		
	
	if number <> 0:
        	for i in d:
                        i_split =  i['WA'].split(';')
                        scc4_set= i_split[0].strip() + ';'+ i_split[1].strip() + ';' + i_split[2].strip() + ';' + i_split[3].strip() + ';' + i_split[4].strip() + ';' + i_split[5].strip() + ';' + i_split[6].strip() + ';' + i_split[7].strip() + ';' + i_split[8].strip()
                        number += 1
			scc4=i_split[2]+i_split[3]+i_split[4]+i_split[5]+i_split[6]

	if scc4 == sys.argv[3]:
		print 'OK: SCC4 settings in System are as expected = ' + sys.argv[3] + " - " + scc4_set + "|num=1"
	else:
                if "warning" == sys.argv[4]:
			print "WARNING: SCC4 settings in System are NOT as expected " + scc4 +" != " + sys.argv[3] + " - " + scc4_set + "|num=0"
	                sys.exit(1)
		else:
			print "CRITICAL: SCC4 settings in System are NOT as expected " + scc4 +" != " + sys.argv[3] + " - " + scc4_set + "|num=0"
                        sys.exit(2)

        conn.close()
#	print "closing..."



except sapnwrfc.RFCCommunicationError:
	print "bang!"
        if 'NO_DATA_FOUND' in e[0]:
                print "No data."
        else:
                print "UKNOWN:" + e[0]
                sys.exit(3)


