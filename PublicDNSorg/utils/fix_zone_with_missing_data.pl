#!/usr/bin/perl
# ex: set tabstop=4 expandtab smarttab softtabstop=4 shiftwidth=4:

=head1 NAME

fix_zone_with_missing_data.pl - Public-DNS.org database maintenance script. This script find all zones that were added without any resource records, and is capable of fixing them for you. You'll probably never need it, but it's handy just to check once in a while to make sure everything is doing well.

=head1 SYNOPSIS

 perl fix_zone_with_missing_data.pl
 (follow the prompts)

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
use PublicDNS::DBlib;
use PublicDNS::Utils;
use PublicDNS::Config;

my $cfg = PublicDNS::Config::load_cfg() or die "Unable to load config file.";

my $our_dns_server   = $cfg->{'dig_settings'}->{'our_dns_server_name'}  || 'dig_settings.our_dns_server_name.not.set';
my @our_dns_servers  = split(',', $cfg->{'dig_settings'}->{'our_dns_server_name_list'});
@our_dns_servers     = ($our_dns_server) unless @our_dns_servers;
my %our_dns_servers  = map { $_ => 1 } @our_dns_servers;

&main;

sub main
{
    my $get = IteratedSQLSelect("Cid,zone,tld,master","conf");
    while (my ($cid,$zone,$tld,$master) = $get->fetchrow_array)
    {
        next if $master;    # skip slaves

        my $rrexists = SQLSelect('RRid','RRs','Cid = ' . SQLQuote($cid));
        unless ($rrexists)
        {
            {
                print "No RRs for $cid - $zone.$tld, update? [y|n] ";
                my $yn = <STDIN>;
                chomp($yn);
                if ($yn =~ /^[yY]$/)
                {
                    &update($cid,$zone,$tld);
                } else {
                    print "\tok, skipping\n";
                }
            }
            {
                print "\tsend dbfiledata? [y|n] ";
                my $yn = <STDIN>;
                chomp($yn);
                if ($yn =~ /^[yY]$/)
                {
                    &senddata($cid,$zone,$tld);
                } else {
                    print "\tok, skipping\n";
                }
            }
        }
    }
    $get->finish;
}

sub update
{
    my ($new_cid,$zone,$tld) = @_;
    my $slave = 0;
    my $master; # we don't touch slaves in this script

    # add in our NS records
    foreach my $dns_server (@our_dns_servers)
    {
        $dns_server .= '.' unless $dns_server =~ /\.$/;
        my $old_rrid = SQLSelect("max(RRid)","RRs");
        SQLInsert("RRs",['RRid','Cid','record','type'],
                        ['NULL',$new_cid,"$zone.$tld.",'NS'] );
        my $new_rrid = SQLSelect("max(RRid)","RRs");
        if ($new_rrid > $old_rrid)
        {
            SQLInsert("RR_NS",['RRid','value'],[$new_rrid,$dns_server]);
        }
    }
    # add default A record for domain
    my $old4_rrid = SQLSelect("max(RRid)","RRs");
    SQLInsert("RRs",['RRid','Cid','record','type'],
                    ['NULL',$new_cid,"$zone.$tld.",'A'] );
    my $new4_rrid = SQLSelect("max(RRid)","RRs");
    if ($new4_rrid > $old4_rrid)
    {
        SQLInsert("RR_A",['RRid','A','B','C','D'],[$new4_rrid,127,0,0,1]);
    }
    # add default mail A record for domain
    my $old5_rrid = SQLSelect("max(RRid)","RRs");
    SQLInsert("RRs",['RRid','Cid','record','type'],
                    ['NULL',$new_cid,"mail.$zone.$tld.",'A'] );
    my $new5_rrid = SQLSelect("max(RRid)","RRs");
    if ($new5_rrid > $old5_rrid)
    {
        SQLInsert("RR_A",['RRid','A','B','C','D'],[$new5_rrid,127,0,0,1]);
    }
    # add default MX record for domain
    my $old6_rrid = SQLSelect("max(RRid)","RRs");
    SQLInsert("RRs",['RRid','Cid','record','type'],
                    ['NULL',$new_cid,"$zone.$tld.",'MX'] );
    my $new6_rrid = SQLSelect("max(RRid)","RRs");
    if ($new6_rrid > $old6_rrid)
    {
        SQLInsert("RR_MX",['RRid','pref','value'],[$new6_rrid,10,"mail.$zone.$tld."]);
    }
}

sub senddata
{
    my ($new_cid,$zone,$tld) = @_;

    my $sock = new IO::Socket::INET (
        LocalAddr   => $cfg->{'daemon'}->{'webserver_addr'} || '',
        PeerAddr    => $cfg->{'daemon_master'}->{'addr'},
        PeerPort    => $cfg->{'daemon_master'}->{'port'} || 5201,
        Proto       => 'tcp'
        );
    if ($sock)
    {
#       if ($slave)
#       {
#           my $query = encrypt( ('addslave',"$zone.$tld",$new_cid,$master,1) );
#           print $sock $query;
#           close($sock);
#       } else {
            my $dbfile_data = &build_db_file($new_cid);
            my $query = encrypt( ('update',"$zone.$tld",$new_cid,$dbfile_data,1) );
#           my $query = encrypt( ('add',"$zone.$tld",$new_cid,$dbfile_data,1) );
            print $sock $query;
            close($sock);
#       }
    } else { # end if $sock
        warn "sending command to master dns daemon failed!\n";
    }
}
