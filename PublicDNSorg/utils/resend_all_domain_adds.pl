#!/usr/bin/perl
# ex: set tabstop=4 expandtab smarttab softtabstop=4 shiftwidth=4:

=head1 NAME

resend_all_domain_adds.pl - Public-DNS.org utility to completely repopulate a name server from scratch. This will send a request to the pdsysd.pl daemon on the primary name server to add every domain in the database, one by one (good for turning up a new name server install).

=head1 SYNOPSIS

 perl resend_all_domain_adds.pl

BE CAREFUL! This doesn't prompt or anything... it'll just start shooting out domain add requests :-)

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


use strict;
use PublicDNS::CryptWrapper;
use PublicDNS::Utils;
use PublicDNS::DBlib;
use IO::Socket::INET;
use PublicDNS::Config;

my $cfg = PublicDNS::Config::load_cfg() or die "Unable to load config file.";

my $get = IteratedSQLSelect("cid,zone,tld","conf");
while (my ($cid,$zone,$tld) = $get->fetchrow_array)
{
    &add($cid,$zone,$tld);
}
$get->finish;

sub add
{
    my $cid = shift;
    my $zone = shift;
    my $tld = shift;
    warn "adding [$zone.$tld][$cid]\n";
    my $sock = new IO::Socket::INET (
        LocalAddr   => $cfg->{'daemon'}->{'webserver_addr'} || '',
        PeerAddr    => $cfg->{'daemon_master'}->{'addr'},
        PeerPort    => $cfg->{'daemon_master'}->{'port'} || 5201,
        Proto       => 'tcp'
        );
    my $dbfile_data = &build_db_file($cid);
    my $query = encrypt( ('add',"$zone.$tld",$cid,$dbfile_data,0) );
    print $sock $query;
    close($sock);
}
