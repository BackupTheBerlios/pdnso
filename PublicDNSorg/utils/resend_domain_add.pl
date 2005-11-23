#!/usr/bin/perl
# ex: set tabstop=4 expandtab smarttab softtabstop=4 shiftwidth=4:

# $Source: /home/xubuntu/berlios_backup/github/tmp-cvs/pdnso/Repository/PublicDNSorg/utils/resend_domain_add.pl,v $
# $Revision: 1.1 $
# $Date: 2005/11/23 03:42:57 $
# $Author: unrtst $

=head1 NAME

resend_domain_add.pl - Public-DNS.org utility to resend a request for domain addition to the pdsysd.pl daemon on the primary name server. Good for any time the two systems get out of sync.

=head1 SYNOPSIS

 perl resend_domain_add.pl (domain name)

OR

 perl resend_domain_add.pl
 (follow prompts)

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
use IO::Socket;
use PublicDNS::CryptWrapper;
use PublicDNS::DBlib;
use PublicDNS::Utils;
use PublicDNS::Config;

my $cfg = PublicDNS::Config::load_cfg() or die "Unable to load config file.";

my $domain = $ARGV[0];

    my @valid_tlds_regex;
    my %valid_tlds;
    my $get_tlds = IteratedSQLSelect("TLD","tlds","","ORDER BY TLD");
    while( my ($t_tld) = $get_tlds->fetchrow_array)
    {
        push(@valid_tlds_regex,"\Q$t_tld\E");   # push tld, escaped for regex, into array
        $valid_tlds{lc($t_tld)}++;
    }
    $get_tlds->finish;
    my $valid_tlds_regex = '(' . join('|',@valid_tlds_regex) . ')';

my $valid_domain_chars = "A-Za-z0-9\\.-";
$domain =~ /^([$valid_domain_chars]+?)\.$valid_tlds_regex\.?$/;
my ($zone,$tld) = ($1,$2);

if (! ($zone && $tld) )
{
    print "no zone specified on command line.\n";
    print "\n";
    my ($zone,$tld) = &ask_for_domain;
    my $Cid = SQLSelect('Cid','conf',
                        'zone = ' . SQLQuote($zone) .
                        ' AND tld = ' . SQLQuote($tld) );
    unless($Cid)
    {
        print "\nInvalid domain submitted. It's not in our database: $zone.$tld\n";
        exit(0);
    }
    &domain_add($Cid);
} else {
    my $Cid = SQLSelect('Cid','conf',
                        'zone = ' . SQLQuote($zone) .
                        ' AND tld = ' . SQLQuote($tld) );
    unless($Cid)
    {
        print "\nInvalid domain submitted. It's not in our database: $zone.$tld\n";
        exit(0);
    }
    &domain_add($Cid);
}

sub ask_for_domain
{
    my ($domain);
    while (! $domain)
    {
        print "Please enter a domain to add: ";
        my $domain = <STDIN>;
        chomp($domain);
        $domain =~ s/[\s\n\r]+//g;
        $domain =~ /^(.+)\.([^\.]+)\.?$/;
        my ($zone,$tld) = ($1,$2);
        if ($zone && $tld) { return ($zone,$tld); }
        $domain = "";
    }
}

sub domain_add
{
    my $Cid = shift;

    my ($ownerid,$zone,$tld,$master) = SQLSelect('ownerid,zone,tld,master','conf',"Cid = $Cid");

    print "adding domain $zone.$tld\n";

    my $sock = new IO::Socket::INET (
        LocalAddr   => $cfg->{'daemon'}->{'webserver_addr'} || '',
        PeerAddr    => $cfg->{'daemon_master'}->{'addr'},
        PeerPort    => $cfg->{'daemon_master'}->{'port'} || 5201,
        Proto       => 'tcp'
        );
    if ($sock)
    {
        if ($master)
        {
            print "adding slave pointed to $master\n";
            my $query = encrypt( ('addslave',"$zone.$tld",$Cid,$master,1) );
            print $sock $query;
            close($sock);
        } else {
            print "adding master\n";
            my $dbfile_data = &build_db_file($Cid);
            my $query = encrypt( ('add',"$zone.$tld",$Cid,$dbfile_data,1) );
            print $sock $query;
            close($sock);
        }
    } else {
        print "Failed while trying to connect to ".$cfg->{'daemon_master'}->{'addr'}."\n";
        exit(0);
    }

}
