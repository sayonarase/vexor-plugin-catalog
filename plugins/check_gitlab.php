#!/usr/bin/php
<?php
//Nagios Exit Codes
$OK = "0";
$WARNING = "1";
$CRITICAL = "2";
$UNKNOWN = "3";
//Exit Strings
$OK_STR = "Gitlab is OK! Nothing to see.";
$WARN_STR = "Warning! Gitlab is in an Unhealthy Status!";
$CRIT_STR = "Gitlab's JSON monitoring is reporting a status other than 'ok'. Check Monitoring and Logs for details.";
$UNK_STR = "Uh OH! Script is broken!";

//replace example.com with your Gitlab health status URL
$json = file_get_contents('example.com');
$output = json_decode($json, true);
$status = $output['status'];
$master = $output['master_check'];

//print_r ($token); 
if ($status == "ok") {
	echo ($OK_STR);
       	exit (0);
}
else if ($status != 'ok') {
	echo $CRIT_STR;
	exit (2);
}
else {
	echo ("Gitlab script is probably broken, it shouldn't have ever made it to this output.");
	exit (3);
}
?>
