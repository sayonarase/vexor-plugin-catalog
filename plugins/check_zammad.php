#!/usr/bin/php
<?php
//Nagios Exit Codes
$OK = "0";
$WARNING = "1";
$CRITICAL = "2";
$UNKNOWN = "3";
//Exit Strings
$OK_STR = "Zammad is OK! Nothing to see.";
$WARN_STR = "Warning! Zammad is in an Unhealthy Status!";
$CRIT_STR = "Critical! Zammad has failed in sending at least 1 message. Checking Monitoring and Logs for details.";
$UNK_STR = "Uh OH! Script is broken!";

//replace example.com with your zammad JSON status URL
$json = file_get_contents('https://example.com');
$output = json_decode($json, true);
$healthy = $output['healthy'];
$message = $output['message'];
$issues = $output['issues'];
$token = $output['token'];

if ($healthy == true) {
        echo ($OK_STR);
        exit (0);
}
else {
        echo ($WARN_STR);
        echo ("Something is off with Zammad. Maybe its just the wind though? Check the monitoring link to be sure.");
        exit (1);
}
if ($message != 'success') {
        echo "Zammad message send failure! Check the logs and the monitoring link for additional details.";
        exit (2);
}
else {
        echo ("Script is probably broken, it shouldn't have made it to this output. Make sure your setup is working.");
        exit (3);
}
//print_r ($array)
?>
