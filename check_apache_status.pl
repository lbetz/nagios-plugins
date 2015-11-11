#!/usr/bin/perl

use Monitoring::Plugin;
use Monitoring::Plugin::Getopt;
use Monitoring::Plugin::Threshold;
use LWP::UserAgent;
use Data::Dumper;

our $VERSION = '1.0.0';

our ( $plugin, $option );

$plugin = Monitoring::Plugin->new( shortname => '' );


$options = Monitoring::Plugin::Getopt->new(
  usage   => 'Usage: %s [OPTIONS]',
  version => $VERSION,
  url     => 'https://github.com/lbetz/nagios-plugins',
  blurb   => 'Check apache server status',
);

$options->arg(
  spec     => 'hostname|H=s',
  help     => 'hostname or ip address to check',
  required => 1,
);

$options->arg(
  spec     => 'port|p=i',
  help     => 'port, default 80 (http) or 443 (https)',
  required => 0,
);

$options->arg(
  spec     => 'uri|u=s',
  help     => 'uri, default /server-status',
  required => 0,
  default => '/server-status',
);

$options->arg(
  spec     => 'ssl|s+',
  help     => 'use https instead of http',
  required => 0,
);

$options->arg(
  spec     => 'warning|w=s',
  help     => 'warning threshold',
  required => 0,
);

$options->arg(
  spec     => 'critical|c=s',
  help     => 'critical threshold',
  required => 0,
);

$options->arg(
  spec     => 'threshold=s',
  help     => 'set threshold for slots (default), busy or idle',
  required => 0,
  default  => 'slots',
);

$options->getopts();
alarm $options->timeout;

$threshold = Monitoring::Plugin::Threshold->set_thresholds(
  warning  => $options->warning,
  critical => $options->critical,
);

my $ua = LWP::UserAgent->new( protocols_allowed => ['http','https'], timeout => 15);

if (defined($options->ssl)) {
  $proto = 'https://';
} else {
  $proto = "http://";
}

if (defined($options->port)) {
  $request = HTTP::Request->new(GET => $proto.$options->hostname.':'.$options->port.$options->uri.'/?auto');
} else {
  $request = HTTP::Request->new(GET => $proto.$options->hostname.$options->uri.'/?auto');
}

$response = $ua->request($request);

if ($response->is_success) {
  $response->content =~ /(?s).*BusyWorkers:\s([0-9]+).*IdleWorkers:\s([0-9]+).*Scoreboard:\s(.*)$/;

  $BusyWorkers = $1;
  $IdleWorkers = $2;
  $OpenSlots   = ($3 =~ tr/\.//);

  $output = 'OpenSlots:'.$OpenSlots.' BusyWorkers:'.$BusyWorkers.' IdleWorkers:'.$IdleWorkers;

  if ($options->threshold =~ /slots/) {
    $plugin->add_perfdata(
      label => 'OpenSlots',
      value => $OpenSlots,
      uom   => q{},
      threshold => $threshold,
    );
    $status = $OpenSlots;
  } else {
    $plugin->add_perfdata(
      label => 'OpenSlots',
      value => $OpenSlots,
      uom   => q{},
    );
  }

  if ($options->threshold =~ /busy/) {
    $plugin->add_perfdata(
      label => 'BusyWorkers',
      value => $BusyWorkers,
      uom   => q{},
      threshold => $threshold,
    );
    $status = $BusyWorkers;
  } else {
    $plugin->add_perfdata(
      label => 'BusyWorkers',
      value => $BusyWorkers,
      uom   => q{},
    );
  }

  if ($options->threshold =~ /idle/) {
    $plugin->add_perfdata(
      label => 'IdleWorkers',
      value => $IdleWorkers,
      uom   => q{},
      threshold => $threshold,
    );
    $status = $IdleWorkers;
  } else {
    $plugin->add_perfdata(
      label => 'IdleWorkers',
      value => $IdleWorkers,
      uom   => q{},
    );
  }

  $plugin->nagios_exit( $threshold->get_status($status), $output );

} else {

  $plugin->plugin_exit( UNKNOWN, $response->headers->title );

}
