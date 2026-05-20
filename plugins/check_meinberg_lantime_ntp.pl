#!/usr/bin/perl
# SPDX-FileCopyrightText: PhiBo from DinoTools (2022)
# SPDX-License-Identifier: GPL-3.0-or-later

use strict;
use warnings FATAL => 'all';

use Pod::Text::Termcap;

use Net::SNMP;

use constant OK         => 0;
use constant WARNING    => 1;
use constant CRITICAL   => 2;
use constant UNKNOWN    => 3;

my $pkg_monitoring_available = 0;
BEGIN {
    my $pkg_nagios_available = 0;
    eval {
        require Monitoring::Plugin;
        require Monitoring::Plugin::Functions;
        require Monitoring::Plugin::Threshold;
        $pkg_monitoring_available = 1;
    };
    if (!$pkg_monitoring_available) {
        eval {
            require Nagios::Plugin;
            require Nagios::Plugin::Functions;
            require Nagios::Plugin::Threshold;
            *Monitoring::Plugin:: = *Nagios::Plugin::;
            $pkg_nagios_available = 1;
        };
    }
    if (!$pkg_monitoring_available && !$pkg_nagios_available) {
        print("UNKNOWN - Unable to find module Monitoring::Plugin or Nagios::Plugin\n");
        exit UNKNOWN;
    }
}

my @g_long_message;
my $parser = Pod::Text::Termcap->new (sentence => 0, width => 78);
my $extra_doc = <<'END_MESSAGE';
END_MESSAGE

my $extra_doc_output;
$parser->output_string(\$extra_doc_output);
$parser->parse_string_document($extra_doc);

my $mp = Monitoring::Plugin->new(
    shortname => "MBG Lantime NTP",
    usage => "",
    extra => $extra_doc_output
);

$mp->add_arg(
    spec    => 'community|C=s',
    help    => 'Community string (Default: public)',
    default => 'public'
);

$mp->add_arg(
    spec     => 'hostname|H=s',
    help     => 'The hostname or IP address of the device.',
    required => 1
);

$mp->add_arg(
    spec    => 'stratum-warning=s',
    help    => 'Warning threshold for the stratum. (Default is empty and will result in no threshold checks)',
    default => '',
);

$mp->add_arg(
    spec    => 'stratum-critical=s',
    help    => 'Critical threshold for the stratum. (Default is empty and will result in no threshold checks)',
    default => '',
);

$mp->add_arg(
    spec    => 'refclock-offset-warning=s',
    help    => 'If use-raw-thresholds is not set this will convert the $threshold to "-$threshold:$threshold" '
                . 'to check if the offset is in the specified range. (Default is empty and will result in no threshold checks)',
    default => '',
);

$mp->add_arg(
    spec    => 'refclock-offset-critical=s',
    help    => 'Have a look at --refclock-offset-warning how this value is handled.',
    default => '',
);

$mp->add_arg(
    spec    => 'use-raw-thresholds',
    help    => 'If set the raw threshold values provided will be used.',
    default => 0,
);

$mp->getopts;

#Open SNMP Session
my ($session, $error) = Net::SNMP->session(
    -hostname => $mp->opts->hostname,
    -version => 'snmpv2c',
    -community => $mp->opts->community,
);

if (!defined($session)) {
    wrap_exit(UNKNOWN, $error)
}

check();

my ($code, $message) = $mp->check_messages();
wrap_exit($code, $message . "\n" . join("\n", @g_long_message));

sub check
{
    my $mbg_base_oid = '1.3.6.1.4.1.5597.30.0.2';
    my $mbgLtNgNtpCurrentState = $mbg_base_oid . '.1.0';
    my $mbgLtNgNtpStratum = $mbg_base_oid . '.2.0';
    my $mbgLtNgNtpRefclockName = $mbg_base_oid . '.3.0';
    my $mbgLtNgNtpRefclockOffset = $mbg_base_oid . '.4.0';
    my $mbgLtNgNtpVersion = $mbg_base_oid . '.5.0';

    my %ntp_current_state = (
        0 => 'n/a',
        1 => 'notSynchronized',
        2 => 'synchronized',
    );

    my $result = $session->get_request(
        -varbindlist => [
            $mbgLtNgNtpCurrentState,
            $mbgLtNgNtpStratum,
            $mbgLtNgNtpRefclockName,
            $mbgLtNgNtpRefclockOffset,
            $mbgLtNgNtpVersion,
        ]
    );

    if(!defined $result) {
        wrap_exit(UNKNOWN, 'Unable to get information');
    }

    my $current_state = $result->{$mbgLtNgNtpCurrentState};

    if ($current_state == 2) {
        $mp->add_message(
            OK,
            'State: ' . $ntp_current_state{$current_state},
        );
    } elsif ($current_state == 1) {
        $mp->add_message(
            CRITICAL,
            'State: ' . $ntp_current_state{$current_state},
        );
    } else {
        $mp->add_message(
            UNKNOWN,
            'State: ' . $ntp_current_state{$current_state},
        );
    }

    my $stratum = $result->{$mbgLtNgNtpStratum};
    my $stratum_threshold = Monitoring::Plugin::Threshold->set_thresholds(
        warning  => $mp->opts->get('stratum-warning'),
        critical => $mp->opts->get('stratum-critical'),
    );

    $mp->add_perfdata(
        label     => 'stratum',
        value     => $stratum,
        threshold => $stratum_threshold,
    );

    $mp->add_message(
        $stratum_threshold->get_status($stratum),
        'Stratum: ' . $stratum,
    );

    my $refclock_offset = $result->{$mbgLtNgNtpRefclockOffset};
    my $refclock_offset_warning = $mp->opts->get('refclock-offset-warning');
    my $refclock_offset_critical = $mp->opts->get('refclock-offset-critical');
    if (!$mp->opts->get('use-raw-thresholds')) {
        $refclock_offset_warning = $refclock_offset_warning ne '' ? sprintf(
            '-%s:%s',
            $refclock_offset_warning,
            $refclock_offset_warning
        ) : undef;
        $refclock_offset_critical = $refclock_offset_critical ne '' ? sprintf(
            '-%s:%s',
            $refclock_offset_critical,
            $refclock_offset_critical
        ) : undef;
    }

    my $refclock_offset_threshold = Monitoring::Plugin::Threshold->set_thresholds(
        warning  => $refclock_offset_warning,
        critical => $refclock_offset_critical,
    );

    $mp->add_perfdata(
        label     => 'refclock-offset',
        value     => $refclock_offset,
        threshold => $refclock_offset_threshold,
        uom       => 'ms',
    );

    $mp->add_message(
        $refclock_offset_threshold->get_status($refclock_offset),
        'Refclock Offset: ' . $refclock_offset . 'ms',
    );

    # $mp->add_message(
    #     OK,
    #     'Refclock Name: ' . $result->{$mbgLtNgNtpRefclockName},
    # );

    # $mp->add_message(
    #     OK,
    #     'NTP Version: ' . $result->{$mbgLtNgNtpVersion},
    # );
}

sub wrap_exit
{
    if($pkg_monitoring_available == 1) {
        $mp->plugin_exit( @_ );
    } else {
        $mp->nagios_exit( @_ );
    }
}
