#!/usr/bin/perl
# ex: set tabstop=4 expandtab smarttab softtabstop=4 shiftwidth=4:

# $Source: /home/xubuntu/berlios_backup/github/tmp-cvs/pdnso/Repository/PublicDNSorg/utils/addtld.pl,v $
# $Revision: 1.1 $
# $Date: 2005/11/23 03:42:57 $
# $Author: unrtst $

=head1 NAME

addtld.pl - Public-DNS.org utility to manually add TLDs to the system.

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

my ($tld, $orderid) = @ARGV;
unless ($tld && $orderid) {
    die "Usage: $0 <tld> <order preference number (1-200)>\n";
}

SQLInsert("tlds", ["TLDid","TLD","orderid"],[undef,$tld,$orderid])
    or die "Unable to add tld [$tld] : $DBI::errstr\n";

