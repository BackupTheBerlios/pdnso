#!/usr/bin/perl
# ex: set tabstop=4 expandtab smarttab softtabstop=4 shiftwidth=4:

=head1 NAME

find_unadded_zones.pl - Public-DNS.org utility to determine if there are any zones which should exist on the name server, but do not.

=head1 SYNOPSIS

ssh username@your_nameserver.net 'ls /etc/namedb/sand/etc/namedb/zones/' | perl find_unadded_zones.pl

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
use PublicDNS::DBlib;

my %zones;
my %zones2;
while (<STDIN>)
{
    chomp($_);
    $zones{lc($_)}++;
    s/^(\d+)\-//;
    $zones2{lc($_)} = $1;
}

#foreach my $key (sort keys %zones2)
#{
#   print "$key:$zones2{$key}\n";
#}

my $sth = IteratedSQLSelect("cid,zone,tld,master","conf");
while (my ($cid,$zone,$tld,$master) = $sth->fetchrow_array)
{
    unless ($zones{lc("$cid-$zone.$tld")})
    {
        print "not found: $cid-$zone.$tld master[$master]\n";
        if ($zones2{lc("$zone.$tld")})
        {
            print "\tfound with id:".$zones2{lc("$zone.$tld")}."\n";
        }
    }
}
$sth->finish;

