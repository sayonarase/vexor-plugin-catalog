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

my @sensors_enabled = ();
my @sensors_available = ('fan', 'ps', 'temperature');

my $pkg_monitoring_available = 0;
BEGIN {
    my $pkg_nagios_available = 0;
    eval {
        require Monitoring::Plugin;
        require Monitoring::Plugin::Functions;
        $pkg_monitoring_available = 1;
    };
    if (!$pkg_monitoring_available) {
        eval {
            require Nagios::Plugin;
            require Nagios::Plugin::Functions;
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
    shortname => "check_meinberg_lantime_hw",
    usage => "",
    extra => $extra_doc_output
);

$mp->add_arg(
    spec    => 'community|C=s',
    help    => 'Community string (Default: public)',
    default => 'public'
);

$mp->add_arg(
    spec => 'hostname|H=s',
    help => '',
    required => 1
);

$mp->add_arg(
    spec    => 'sensor=s@',
    help    => sprintf('Enabled sensors: all, %s (Default: all)', join(', ', @sensors_available)),
    default => []
);

$mp->getopts;

if(@{$mp->opts->sensor} == 0 || grep(/^all$/, @{$mp->opts->sensor})) {
    @sensors_enabled = @sensors_available;
} else {
    foreach my $name (@{$mp->opts->sensor}) {
        if(!grep(/$name/, @sensors_available)) {
            wrap_exit(UNKNOWN, sprintf('Unknown sensor type: %s', $name));
        }
    }
    @sensors_enabled = @{$mp->opts->sensor};
}

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
    if (grep(/^fan$/, @sensors_enabled)) {
        check_fan();
    }
    if (grep(/^ps$/, @sensors_enabled)) {
        check_ps();
    }
    # if (grep(/^system$/, @sensors_enabled)) {
    #     check_system();
    # }
    if (grep(/^temperature$/, @sensors_enabled)) {
        check_temperature();
    }

}

sub check_fan
{
    my $mbgLtNgSysFanTableEntry = '.1.3.6.1.4.1.5597.30.0.5.1.2.1';

    my $result = $session->get_table(
        -baseoid => $mbgLtNgSysFanTableEntry
    );
    if(!defined $result) {
        wrap_exit(UNKNOWN, 'Unable to get information');
    }

    my %fans;
    my %fan_status = (
        0 => 'n/a', # notAvailable
        1 => 'off',
        2 => 'on',
    );

    my %fan_error = (
        0 => 'n/a', # notAvailable
        1 => 'no',
        2 => 'yes',
    );

    foreach (keys %$result) {
        if (/$mbgLtNgSysFanTableEntry\.\d+\.(.*)/) {
            if (!exists($fans{$1})) {
                # print($fans{$1});
                $fans{$1} = {
                     state => $result->{".1.3.6.1.4.1.5597.30.0.5.1.2.1.2.$1"},
                     error => $result->{".1.3.6.1.4.1.5597.30.0.5.1.2.1.3.$1"},
                };
            }

        }
    }

    my $fan_on_count = 0;
    my $fan_off_count = 0;
    my $fan_error_count = 0;
    my $fan_na_count = 0;

    foreach my $fan (keys %fans) {
        if ($fans{$fan}->{'error'} == 2) {
            $fan_error_count++;
        } elsif ($fans{$fan}->{'state'} == 1) {
            $fan_off_count++;
        } elsif ($fans{$fan}->{'state'} == 2) {
            $fan_on_count++;
        } else {
            $fan_na_count++;
        }
    }

    $mp->add_perfdata(
        label     => 'fan_on_count',
        value     => $fan_on_count,
    );

    $mp->add_perfdata(
        label     => 'fan_off_count',
        value     => $fan_off_count,
    );

    $mp->add_perfdata(
        label     => 'fan_na_count',
        value     => $fan_na_count,
    );

    my $threshold = Monitoring::Plugin::Threshold->set_thresholds(
        warning   => 1,
        critical  => 2
    );

    my $perf_fan_error_count = $mp->add_perfdata(
        label     => 'fan_error_count',
        value     => $fan_error_count,
        threshold => $threshold,
    );

    my $error_status = $threshold->get_status($fan_error_count);

    foreach my $fan (sort keys %fans) {
        if ($fans{$fan}->{'error'} == 2) {
            $mp->add_message($error_status, 'Fan ' . $fan . ': error');
        } else {
            $mp->add_message(OK, 'Fan ' . $fan . ': ' . $fan_status{$fans{$fan}->{'state'}});
        }
    }
}

sub check_ps
{
    my $mbgLtNgSysPsTableEntry = '1.3.6.1.4.1.5597.30.0.5.0.2.1';
    my $mbgLtNgSysPsStatus = $mbgLtNgSysPsTableEntry . '.2';

    my $result = $session->get_table(
        -baseoid => $mbgLtNgSysPsTableEntry
    );
    if(!defined $result) {
        wrap_exit(UNKNOWN, 'Unable to get information');
    }

    my %power_supplies;
    my %ps_status = (
        0 => 'n/a', # notAvailable
        1 => 'down',
        2 => 'up',
    );

    foreach (keys %$result) {
        if (/$mbgLtNgSysPsTableEntry\.\d+\.(.*)/) {
            if (!exists($power_supplies{$1})) {
                $power_supplies{$1} = {
                     status => $result->{$mbgLtNgSysPsStatus . '.' . $1},
                };
            }

        }
    }

    my $ps_up_count = 0;
    my $ps_down_count = 0;
    my $ps_na_count = 0;

    foreach my $ps_id (keys %power_supplies) {
        if ($power_supplies{$ps_id}->{'status'} == 1) {
            $ps_down_count++;
        } elsif ($power_supplies{$ps_id}->{'status'} == 2) {
            $ps_up_count++;
        } else {
            $ps_na_count++;
        }
    }

    $mp->add_perfdata(
        label     => 'ps_up_count',
        value     => $ps_up_count,
    );

    $mp->add_perfdata(
        label     => 'ps_down_count',
        value     => $ps_down_count,
    );

    $mp->add_perfdata(
        label     => 'ps_na_count',
        value     => $ps_na_count,
    );

    my $threshold = Monitoring::Plugin::Threshold->set_thresholds(
        warning   => 1,
        critical  => 2,
    );

    my $perf_fan_error_count = $mp->add_perfdata(
        label     => 'ps_down_count',
        value     => $ps_down_count,
        threshold => $threshold,
    );

    my $down_status = $threshold->get_status($ps_down_count);

    foreach my $ps_id (sort keys %power_supplies) {
        if ($power_supplies{$ps_id}->{'status'} == 1) {
            $mp->add_message($down_status, 'PS ' . $ps_id . ': down');
        } else {
            if ($power_supplies{$ps_id}->{'status'} > 0 ) {
                $mp->add_message(OK, 'PS ' . $ps_id . ': ' . $ps_status{$power_supplies{$ps_id}->{'status'}});
            }
        }

    }
}

sub check_temperature
{
    my $mbgLtNgSysTempCelsius = '1.3.6.1.4.1.5597.30.0.5.2.1.0';

    my $result = $session->get_request(
        -varbindlist => [
            $mbgLtNgSysTempCelsius,
        ]
    );
    if(!defined $result) {
        wrap_exit(UNKNOWN, 'Unable to get temperature information');
    }

    my $temperature = $result->{$mbgLtNgSysTempCelsius};

    my $threshold = Monitoring::Plugin::Threshold->set_thresholds(
        warning   => 80,
        critical  => 90,
    );

    my $perf_fan_error_count = $mp->add_perfdata(
        label     => 'temperature',
        value     => $temperature,
        threshold => $threshold,
        uom       => 'C',
    );

    $mp->add_message(
        $threshold->get_status($temperature),
        'Temperature: ' . $temperature . '°C',
    );
}

sub wrap_exit
{
    if($pkg_monitoring_available == 1) {
        $mp->plugin_exit( @_ );
    } else {
        $mp->nagios_exit( @_ );
    }
}
