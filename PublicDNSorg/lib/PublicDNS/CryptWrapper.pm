package PublicDNS::CryptWrapper;
# ex: set tabstop=4 expandtab smarttab softtabstop=4 shiftwidth=4:

# TODO This may have a bug in it. It broke upon first deployment, 
#      and I caught the error in the logs, but have not been able to
#      reproduce it.
#[Sat Nov 19 16:43:50 2005] [error] Undefined subroutine &PublicDNS::Config::load_cfg called at /usr/local/apache/public_dns_demo/lib/PublicDNS/CryptWrapper.pm line 38.
#BEGIN failed--compilation aborted at /usr/local/apache/public_dns_demo/lib/PublicDNS/CryptWrapper.pm line 48.
#Compilation failed in require at /usr/local/apache/public_dns_demo/lib/PublicDNS/Utils.pm line 34.
#BEGIN failed--compilation aborted at /usr/local/apache/public_dns_demo/lib/PublicDNS/Utils.pm line 34.
#Compilation failed in require at /usr/local/apache/public_dns_demo/lib/PublicDNS/Auth.pm line 58.
#BEGIN failed--compilation aborted at /usr/local/apache/public_dns_demo/lib/PublicDNS/Auth.pm line 58.
#Compilation failed in require at /usr/local/apache/public_dns_demo/html/status.html line 14.
#BEGIN failed--compilation aborted at /usr/local/apache/public_dns_demo/html/status.html line 14.
#
#[Sat Nov 19 16:56:42 2005] [error] Undefined subroutine &PublicDNS::Config::load_cfg called at /usr/local/apache/public_dns_demo/lib/PublicDNS/CryptWrapper.pm line 38.
#BEGIN failed--compilation aborted at /usr/local/apache/public_dns_demo/lib/PublicDNS/CryptWrapper.pm line 48.
#Compilation failed in require at /usr/local/apache/public_dns_demo/html/list.html line 15.
#BEGIN failed--compilation aborted at /usr/local/apache/public_dns_demo/html/list.html line 15.
#

=head1 NAME

PublicDNS::CryptWrapper - Public-DNS.org encryption routine wrappers.

=head1 TODO

This was created soley due to Crypt::Simple support in the existing codebase, and its infexability. Mainly, that it can NOT be configured with a non-standard passphrase without jumping through some odd hoops.... which is what this wrapper does (jumps through the hoops for you).

This WILL BE GOING AWAY. And so will our dependancy on Crypt::Simple.

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

# $Source: /home/xubuntu/berlios_backup/github/tmp-cvs/pdnso/Repository/PublicDNSorg/lib/PublicDNS/CryptWrapper.pm,v $
# $Revision: 1.1 $
# $Date: 2007/09/13 05:53:04 $
# $Author: unrtst $

use strict;

BEGIN {
    use strict;
    use PublicDNS::Config;
    my $cfg = PublicDNS::Config::load_cfg();

    use vars qw($passphrase);
    $passphrase = $cfg->{'daemon'}{'passphrase'} || 'default_public_dns_passphrase';
    eval "use Crypt::Simple passphrase => '$passphrase';";

    require Exporter;
    use vars qw(@ISA @EXPORT);
    @ISA = ('Exporter');
    @EXPORT = qw(encrypt decrypt);
};

1;
