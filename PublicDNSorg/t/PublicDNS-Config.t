#!/usr/bin/perl
# ex: set tabstop=4 expandtab smarttab softtabstop=4 shiftwidth=4:

=head1 NAME

PublicDNS-Config.t - Public-DNS.org Config.pm library test script.

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
use PublicDNS::Config;

my $cfg = &PublicDNS::Config::load_cfg() or die "Unable to load config file.";

print "DUMPING CONFIG\n==============\n";
foreach my $section (sort keys %{$cfg})
{
    print "[$section]\n";
    my $max_length = length( (sort { length($b) <=> length($a) } keys %{$cfg->{$section}})[0] );
    foreach my $key (sort keys %{$cfg->{$section}})
    {
        printf '%-'.$max_length.'s = %-s'."\n", $key, $cfg->{$section}->{$key};
    }
}
