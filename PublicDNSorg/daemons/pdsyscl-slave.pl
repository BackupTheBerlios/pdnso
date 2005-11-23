#!/usr/bin/perl
# ex: set tabstop=4 expandtab smarttab softtabstop=4 shiftwidth=4:

# $Source: /home/xubuntu/berlios_backup/github/tmp-cvs/pdnso/Repository/PublicDNSorg/daemons/pdsyscl-slave.pl,v $
# $Revision: 1.1 $
# $Date: 2005/11/23 03:42:57 $
# $Author: unrtst $

=head1 NAME

pdsyscl_slave.pl - Public-DNS.org client script to control pdsysd_slave.pl slaves.

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

use IO::Socket;
use PublicDNS::Config;
use PublicDNS::CryptWrapper;

if ($ARGV[0] eq '' || $ARGV[1] eq '' || $ARGV[2] eq '' || $ARGV[3] eq '')
{
    print "usage: pdsyscl-slave.pl DOMAIN ID IP CMD\n";
    print "       DOMAIN- doamain that you want to slave\n";
    print "       ID    - ZonedID\n";
    print "       IP    - IP Address of the master name-server\n";
    print "       CMD   - 0 for reload later 1 for now\n";
    exit(0);
}
my $cfg = PublicDNS::Config::load_cfg() or die "Unable to load config file.";
my $sock = new IO::Socket::INET (
                LocalAddr   => $cfg->{'daemon'}->{'webserver_addr'} || '',
                PeerAddr    => $cfg->{'daemon_master'}->{'addr'},
                PeerPort    => $cfg->{'daemon_master'}->{'port'} || 5201,
                Proto       => 'tcp'
                 );


my @stuff = ('addslave',$ARGV[0],$ARGV[1],$ARGV[2],$ARGV[3]);
my $data = encrypt(@stuff);
print $sock $data;
close($sock);

