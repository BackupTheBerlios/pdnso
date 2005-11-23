#!/usr/bin/perl
# ex: set tabstop=4 expandtab smarttab softtabstop=4 shiftwidth=4:

=head1 NAME

send_reconfig.pl - Public-DNS.org utility to send a request to the master pdsysd.pl daemon, requesting a name server "reconfig" (reloading the named.conf).

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

my $cfg = PublicDNS::Config::load_cfg() or die "Unable to load config file.";

my $sock = new IO::Socket::INET (
                LocalAddr   => $cfg->{'daemon'}->{'webserver_addr'} || '',
                PeerAddr    => $cfg->{'daemon_master'}->{'addr'},
                PeerPort    => $cfg->{'daemon_master'}->{'port'} || 5201,
                Proto       => 'tcp'
                 );


my @stuff = ('system','reconfig',1);
my $data = encrypt(@stuff);
print $sock $data;
close($sock);

