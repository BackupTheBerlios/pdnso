#!/usr/bin/perl
# ex: set tabstop=4 expandtab smarttab softtabstop=4 shiftwidth=4:

=head1 NAME

test_domain.pl - Public-DNS.org utility to quickly test to see if a domain is formatted ok, and has the appropriate name servers configured (does the same tests that check_pending_domains.cron does).

=head1 SYNOPSIS

perl test_domain.pl (domain name)

=head1 AUTHOR

Joshua I. Miller <unrtst@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2002 by PurifiedData, LLC.

This library is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License version 2 as
published by the Free Software Foundation. (see COPYING)

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
02111-1307, USA

=cut

my $test_domain = $ARGV[0];
die "Usage: $0 [domain_to_test]\n" unless $test_domain;

use strict;
use Net::DNS::Resolver::Recurse; # use of dig is depreciated
use PublicDNS::DBlib;
use PublicDNS::Utils;
use PublicDNS::Config;

my $cfg = PublicDNS::Config::load_cfg() or die "Unable to load config file.";

my $DEBUG = 0;

my @root_dns_servers = split(',', $cfg->{'dig_settings'}->{'root_name_servers'});
@root_dns_servers    = ('198.41.0.4','192.58.128.30','202.12.27.33','198.32.64.12') unless @root_dns_servers;
my $dig              = $cfg->{'dig_settings'}->{'dig_exe'}              || '/usr/local/bin/dig'; # depreciated
my $our_dns_server   = $cfg->{'dig_settings'}->{'our_dns_server_name'}  || 'dig_settings.our_dns_server_name.not.set';


print "Using net dns version: $Net::DNS::VERSION\n";


my ($config_statuses,$config_statusesmap) = load_config_statuses;

my $dns_handle = Net::DNS::Resolver::Recurse->new;
$dns_handle->debug($DEBUG);
$dns_handle->retry(2);
$dns_handle->hints(@root_dns_servers); # root servers

my $now = time;
my $weekago = $now - (60*60*24*14);
my $notify_period = $now - (60*60*24); # remind them of failures once a day

my $sqlnow = SQLSelect("NOW()");

if (&check_roots($test_domain))
{
    warn "check_roots: PASSED\n";
} else {
    warn "check_roots: FAILED\n";
}


sub check_roots
{
    my $zone = shift;
    $zone .= "." unless ($zone =~ /\.$/);

    my $q_our_dns_server = "\Q$our_dns_server.\E";

    warn "looking at $zone\n" if $DEBUG;
    my $packet = $dns_handle->query_dorecursion($zone,'NS');
    #   should return Net::DNS::Packet object, or undef if no answers found
    if ($DEBUG && $packet) { warn "got packet for $zone\n"; }
    elsif ($DEBUG) { warn "didn't get packet for $zone\n"; }
    return 0 unless $packet;
    foreach my $result ($packet->answer)
    {
        if ($DEBUG && ($result->type eq 'NS'))
        {
            warn "\tNS: " . $result->rdatastr . "\n";
        }
        if (($result->type eq 'NS') && ($result->rdatastr =~ /^$q_our_dns_server$/i))
        {   # found our NS record in their shit, it's cool
            return 1;
        }
    }
    return 0; # didn't find us in their stuff
}

sub check_roots_old
{
    my $zone = shift;
    my $q_our_dns_server = "\Q$our_dns_server\E";

    my @ret_val;
    # safely execute a command without haveing to worry about shell escapes
    my $pid;
    die "cannot fork: $!" unless defined($pid = open(CHILD, "-|"));
    if ($pid)
    {   # parent
        while (<CHILD>)
        {
            push(@ret_val,$_);
        }
        close(CHILD);
    } else {    # child
        exec($dig,$zone,'ns','+noall','+answer');
    }

    foreach(@ret_val)
    {
        next if (/^\s*$/);
        next if (/^;/);
        if (/\s+NS\s+$q_our_dns_server\.\s*$/i)
        {   # found our NS record in their shit, it's cool
            return 1;
        }
    }
}
