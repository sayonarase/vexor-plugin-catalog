#!/usr/bin/env perl

##############################################################################
# Program to check to make sure postgrey is running and report back to nrpe
# for nagios. The variable that you need to change is "$postgrey_socket" which
# is the location of the unix socket interface provided by postgrey or the
# TCP socket parameters "$postgrey_host" and "$postgrey_port".
# Created: 2025-06-18
# Version: 1.1.0
# Author: Alex Schuilenburg
# Contributor: Sascha Nemecek
##############################################################################

use English qw( -no_match_vars );
use Getopt::Long;
use Pod::Usage;
use Time::HiRes;
use IO::Socket::UNIX;
use IO::Socket::IP;
use strict;
use warnings;

my $timeout = 10;
my $mode = 'socket';
my $warn = $timeout / 3;
my $crit = $timeout / 2;
my $postgrey_socket = '/var/spool/postfix/postgrey/socket';
my $postgrey_host = '127.0.0.1';
my $postgrey_port = '10023';
my $VERSION = '1.1.0';

Getopt::Long::Configure( 'bundling', 'gnu_compat', 'no_ignore_case' );

GetOptions( 'man'           => sub { pod2usage(-verbose  => 2) },
            'mode|m=s'      => \$mode,
            'socket|s=s'    => \$postgrey_socket,
            'host|H=s'      => \$postgrey_host,
            'port|p=i'      => \$postgrey_port,
            'timeout|t=i'   => \$timeout,
            'warning|w=s'   => \$warn,
            'critical|c=s'  => \$crit,
            'version|V'     => sub { VersionMessage() },
            'help|h'        => sub { pod2usage(1) },
);

#Make sure postgrey_socket exists and if not give back a nagios error
if ( ($mode eq 'socket') && (!-e $postgrey_socket) ) {
    print "postgrey unix socket $postgrey_socket does not exist.\n";
    exit 2;
}

if ($warn !~ /^(\d*\.\d+|\d+\.?\d*)$/) {
    printf "Invalid warning parameter %s\n", $warn;
    exit 1;
}
if ($crit !~ /^(\d*\.\d+|\d+\.?\d*)$/) {
    printf "Invalid critical parameter %s\n", $crit;
    exit 1;
}

#Timer operation. Times out after $timeout seconds.
my $start_time = Time::HiRes::time;
eval {
    #Set the alarm and set the timeout
    local $SIG{ALRM} = sub { die "alarm\n" };
    alarm $timeout;

    # Attempt to connect
    my $client;
    if ($mode eq 'socket') {
        $client = IO::Socket::UNIX->new(
            Type => SOCK_STREAM(),
            Peer => $postgrey_socket,
        );
    }
    if ($mode eq 'tcp') {
        $client = IO::Socket::IP->new(
            Type => SOCK_STREAM(),
            PeerHost => $postgrey_host,
            PeerPort => $postgrey_port,
        );
    }

    if (not defined $client) {
        print "Permission denied\n";
        exit 1;
    }

my $data = <<EOF;
<<EOF
request=smtpd_access_policy
protocol_state=RCPT
protocol_name=SMTP
helo_name=some.domain.tld
queue_id=8045F2AB23
sender=foo\@bar.tld
recipient=bar\@foo.tld
recipient_count=0
client_address=1.2.3.4
client_name=another.domain.tld
reverse_client_name=another.domain.tld
instance=123.456.7
sasl_method=plain
sasl_username=you
sasl_sender=
size=12345
ccert_subject=solaris9.porcupine.org
ccert_issuer=Wietse+20Venema
ccert_fingerprint=C2:9D:F4:87:71:73:73:D9:18:E7:C2:F3:C1:DA:6E:04
encryption_protocol=TLSv1/SSLv3
encryption_cipher=DHE-RSA-AES256-SHA
encryption_keysize=256
etrn_domain=
stress=

EOF

    # Send some test data
    $client->send($data);

    # Read back the expected action
    undef $data;
    my $ret = $client->recv($data,2048,0);
    $client->close();

    # Check if we got any data
    if (not defined $ret) {
        print "No response\n";
        exit 1;
    }

    # Interpret the data
    if ((not defined $data) || ($data !~ /^action=.+/)) {
        print "Remote error in protocol\nUnexpected: $data\n";
        exit 2;
    }

    alarm 0;
};

my $elapsed_time = Time::HiRes::time - $start_time;

#Test return value and exit if eval caught the alarm
if ($EVAL_ERROR) {
    if ( $EVAL_ERROR eq "alarm\n" ) {
        print "Operation timed out after $timeout seconds.\n";
        exit 2;
    }
    else {
        print "An unknown error has occured: $EVAL_ERROR \n";
        exit 3;
    }
}

# Check for critical
if ($elapsed_time > $crit) {
    printf "CRITICAL: Response time is %.3f\n", $elapsed_time;
    exit 1;
}

# Check for warning
if ($elapsed_time > $warn) {
    printf "WARNING: Response time is %.3f\n", $elapsed_time;
    exit 1;
}

#Give Nagios OK
printf "OK - %.3fs response time|time=%.6fs;%.6f;%.6f;;\n",
    $elapsed_time, $elapsed_time, $warn, $crit;
exit 0;


#Version message information displayed in both --version and --help
sub main::VersionMessage {
    print <<"EOF";
This is version $VERSION of check_postgrey.

Copyright (c) 2015 Alex Schuilenburg (alexs\@ecoscentric.com).
All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License.
See http://www.fsf.org/licensing/licenses/gpl.html

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

EOF

    exit 1;
}
__END__

=head1 NAME

check_postgrey - Checks the status of the PostGrey policy server

=head1 VERSION

This documentation refer.0.2

=head1 USAGE

check_postgrey.pl

=head1 REQUIRED ARGUMENTS

None

=head1 OPTIONS

 --mode      (-m)     The connection mode: 'socket' or 'tcp'.
 --socket    (-s)     Set the location of the postgrey socket.
 --host      (-H)     Set the ip or hostname ot the postgrey service.
 --port      (-p)     Set the port of the postgrey service.
 --timeout   (-t)     Sets the timeout, defaults to 10 seconds.
 --warning=  (-w)     Sets the warning period for the response time.
 --critical= (-c)     Sets the critical period for the response time.
 --version   (-V)     Display current version and exit.
 --help      (- exit


=head1 DESCRIPTION

This is a Nagios plugin that checks the status of a postgrey server that has been
configured to listen on a unix socket or a port. It connects to a running postgrey server
and sends an example postfix policy request, parses the result toropriate NAGIOS/NRPE response.

=head1 DIAGNOSTICS

=head2 socket does not exist:

The postgrey unix socket does not exist where the plugin is looking for it.
By default check_postgrey looks for the socket in /var/spool/postfix/postgrey/socket
This may not be the location of the socketm. Change the
variable $postgrey_socket to fix this issue or add the -s parameter to
specify the correct location.

=head1 CONFIGURATION AND ENVIRONMENT

check_postgrey must be available on the system being checked.

=head1 DEPENDENCIES

check_postgrey depends on the following modules:
    Getopt::Std       Standard Perl 5.8 module
    Time::HiRes       Standard Perl 5.8 module
    IO::Socket::UNIX
    IO::Socket::IP

No known bugs. If you encounter any let me know.
(alexs@ecoscentric.com)

Currently unix and TCP sockets are supported.

=head1 AUTHOR

Alex Schuilenburg (alexs@ecoscentric.com)

=head1 CONTRIBUTORS

Sascha Nemecek (nemecek@wienfluss.net)

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2015 Alex Schuilenburg (alexs@ecoscentric.com)
All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License.
See L<http://www.fsf.org/licensing/licenses/gpl.html>.

This program is distributed in the hope that it will be useful,ranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
