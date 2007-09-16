package PublicDNS::Config;
# ex: set tabstop=4 expandtab smarttab softtabstop=4 shiftwidth=4:

# $Revision: 1.2 $
# $Date: 2007/09/16 22:56:09 $

=head1 NAME

PublicDNS::Config - Public-DNS.org configuration library.

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

use vars qw($VERSION);
$VERSION = '2.002';

use strict;
use Config::Tiny();
use File::Basename();
use File::Spec();
use Carp qw(croak carp);

my $cache = { };
my $cache_timer = 0;

sub load_cfg
{
    my $cfg = shift || '';

    # determine config file to use
    my $cfg_file;
    if (-e $cfg)
    {
        $cfg_file = $cfg;
    } else {
        # find config file location
        my $this_file = __FILE__;
        my $dirname   = File::Basename::dirname($this_file);
        my @dir       = File::Spec->splitdir($dirname);
        $cfg_file  = File::Spec->catfile(@dir,'Config.ini');
    }

    # if we can't read config, return what we had if possible, or error out.
    if ( (! -e $cfg_file) || (! -r $cfg_file) )
    {
        if (ref($cache) && ref($cache->{'system'}) && $cache->{'system'}->{'VERSION'})
        {
            return $cache;
        } else {
            croak "Error reading config file [$cfg_file].\n";
        }
    }

    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
        $atime,$mtime,$ctime,$blksize,$blocks) = stat($cfg_file);

    # if config file has been updated, re-read it
    if ($mtime > $cache_timer)
    {
        $cache    = Config::Tiny->read( $cfg_file );

        $cache->{'system'}{'VERSION'} = $VERSION;

        $cache_timer = $mtime;
        return $cache;

    # otherwise, return the cached copy
    } else {
        return $cache;
    }
}

1;

