package PublicDNS::Utils;
# ex: set tabstop=4 expandtab smarttab softtabstop=4 shiftwidth=4:

=head1 NAME

PublicDNS::Utils - Public-DNS.org utilities.

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

# $Source: /home/xubuntu/berlios_backup/github/tmp-cvs/pdnso/Repository/PublicDNSorg/lib/PublicDNS/Utils.pm,v $
# $Revision: 1.1 $
# $Date: 2007/09/13 05:53:04 $
# $Author: unrtst $

use strict;
use Net::SMTP;
use CGI qw(:standard);
use HTML::Template;
use Digest::MD5;
use IO::Socket;
use PublicDNS::Config();
use PublicDNS::CryptWrapper;
use PublicDNS::DBlib;

my $cfg = PublicDNS::Config::load_cfg() or die "Unable to load config file.";

use vars qw($tmpl_dir);
$tmpl_dir       = $cfg->{'system'}->{'tmpl_dir'};

my $smtphost    = $cfg->{'system'}->{'smtphost'} || 'localhost';
my $soa_auth_ns = $cfg->{'system'}->{'soa_nameserver'};
$soa_auth_ns   .= '.' unless substr($soa_auth_ns,-1,1) eq '.'; # must end in period
my $system_name = $cfg->{'system'}->{'generic_system_name'} || 'Public-DNS.org DNS Management System';

my $valid_domain_chars = "A-Za-z0-9\\.-";
my @type_order = qw(
    NS
    MX
    A
    AAAA
    CNAME
    HINFO
    TXT
    PTR
    );

# seed the random number generator with some decent entropy
srand (time ^ $$ ^ unpack "%32L*", `ps axww | gzip`);

BEGIN {
    require Exporter;
    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
    $VERSION = "1.0";
    @ISA = 'Exporter',
    @EXPORT_OK = ();
    @EXPORT = qw(print_top print_bottom print_error build_valid_record send_mail make_rand_key get_banner build_db_file bad_ipv6_addr load_config_statuses send_domain_delete);
}

sub load_config_statuses
{
    my %statuses = (
        'Active'    => 1,
        'Pending Check' => 2,
        'Check failed'  => 3,
        'Verfied'   => 4,
        'Duplicate' => 5
        );
    my %statusesmap = (
        1   => 'Active',
        2   => 'Pending Check',
        3   => 'Check failed',
        4   => 'Verfied',
        5   => 'Duplicate'
        );
    return (\%statuses,\%statusesmap);
}

sub print_top
{
    my $uid = shift;
    my $thisscript = shift;
    my $title = shift;
    my $login;
    $login = SQLSelect("login","logins","uid = $uid") if $uid;
    print header;

    my $banner = &get_banner;

    my $tmpl = HTML::Template->new(filename => $tmpl_dir . '/list_head.tmpl', cache => 1);
    $tmpl->param(TITLE => $title) if $title;
    $tmpl->param(TITLE => $thisscript) unless $title;
    $tmpl->param(DOMAIN => $Q::domain) if $Q::domain;
    $tmpl->param(LOGGEDIN => 1) if $uid;
    $tmpl->param(LOGIN => $login) if $login;
    $tmpl->param(POSTSCRIPT => $thisscript);
    if ($banner)
    {
        $tmpl->param(BANNER => 1);
        $tmpl->param(BANNERURL => $banner->[0]);
        $tmpl->param(BANNERIMG => $banner->[1]);
    }
    # stuff from the config file
    $tmpl->param(MAIN_TITLE    => $cfg->{'page'}->{'title'});
    $tmpl->param(META_DESC     => $cfg->{'page'}->{'meta_desc'});
    $tmpl->param(META_KEYWORDS => $cfg->{'page'}->{'meta_keywords'});
    $tmpl->param(BANNER_TEXT   => $cfg->{'page'}->{'banner_text'});
    $tmpl->param(EXTRA_BANNER  => $cfg->{'page'}->{'extra_banner'});

    print $tmpl->output;
}

sub print_bottom
{
    my $tmpl = HTML::Template->new(filename => $tmpl_dir . '/list_bottom.tmpl', cache => 1);
    print $tmpl->output;
}

sub get_banner
{
    my @banners;
    my $get_banners = IteratedSQLSelect("Preferance,linkurl,bannerurl","banners","active");
    while(my ($pref,$linkurl,$bannerurl) = $get_banners->fetchrow_array)
    {
        for (my $i=0; $i<$pref; $i++)
        {
            push(@banners,[$linkurl,$bannerurl]);
        }
    }
    $get_banners->finish;
    if (@banners)
    {   # if we have any banners in the hold, return one
        my $total_banners = @banners;
        my $random_banner = int( rand( $total_banners ) );
        return($banners[$random_banner]);
    } else {
        return 0;
    }
}

sub make_rand_key
{
    my $length = 128;
    my $key;
    while($length-- > 0)
    {
        $key .= chr(rand(256));
    }
    return Digest::MD5::md5_hex($key);
}

sub build_valid_record
{
    my ($record,$zone,$tld) = @_;
    if ( ($record =~ /^\*\./) || ($record =~ /^\*$/) )
    {   # $record is a wildcard
        $record =~ s/[^\*$valid_domain_chars]//g;
        $record =~ s/-+$//;
    } else {
        # normal record, so screwed up wildcard (like bob.*.domain.com)
        $record =~ s/[^$valid_domain_chars]//g;
        $record =~ s/^-+//;
        $record =~ s/-+$//;
    }

    if ( ($record =~ /\.$/) && ( ($record =~ /.\.$zone\.$tld\.$/i) || ($record =~ /^$zone\.$tld\.$/i) ) )
    {   # no need to do anything, $zone.$tld is correctly at end of record
    } elsif ( ($record =~ /\.$/) && ( ! (($record =~ /.\.$zone\.$tld\.$/i) || ($record =~ /^$zone\.$tld\.$/i)) ) ) {
        # append domain to record (it already ends with period, but not domain
        $record .= $zone . "." . $tld . ".";
    } elsif (($record =~ /\.$zone\.$tld$/i) || ($record =~ /^$zone\.$tld$/i)) {
        # append a period. record ends with $zone.$tld, but not a period.
        # we could be doing the wrong thing here, but it's not very likely
        # they wanted $zone.$tld.$zone.$tld.
        $record .= ".";
    } elsif (length($record)) {
        # there's some valid data in $record, it doesn't end with period,
        # so we need to append what would be the $ORIGIN to it
        $record = join(".",($record,$zone,$tld)) . ".";
    } else {
        # after ditching everything that isn't $valid_domain_chars and stuff
        # we've got nothing left, so make the record $zone.$tld
        $record = $zone . "." . $tld . ".";
    }
    return $record;
}

sub print_error
{
    my $msg = shift;

    my $tmpl = HTML::Template->new(filename => $tmpl_dir . '/error.tmpl', cache => 1);
    $tmpl->param(MSG => $msg);
    print $tmpl->output;

    my $tmpl_bottom = HTML::Template->new(filename => $tmpl_dir . '/list_bottom.tmpl', cache => 1);
    print $tmpl_bottom->output;
}

sub build_db_file
{
    my $Cid = shift;

    my $dbfile_data;

    my ($zone,$tld,$serial,$refresh,$retry,$expire,$ttl,$admin_email) = SQLSelect("zone,tld,serial,refresh,retry,expire,ttl,admin_email","conf","Cid = $Cid");

    return 0 unless ($zone);

    $admin_email =~ s/\@/./g;
    $admin_email = $admin_email . "." if ($admin_email !~ /\.$/);

    $serial++;

    $dbfile_data .= "\$TTL 86400\n\@\tIN\tSOA\t$soa_auth_ns\t$admin_email (
        $serial
        $refresh
        $retry
        $expire
        $ttl )
;
; $system_name - auto-generated zonefile
;\n";

    foreach my $t_type (@type_order)
    {
        $dbfile_data .= "; $t_type records\n";
        my @select_stm;
        if ($t_type eq 'A')
        {
            @select_stm = ("r.RRid,r.record,r.TTL,CONCAT_WS('.',v.A,v.B,v.C,v.D)","RRs r, RR_A v","r.Cid = $Cid AND r.RRid = v.RRid");
        } elsif ($t_type eq "MX") {
            @select_stm = ("r.RRid,r.record,r.TTL,CONCAT_WS(' ',v.pref,v.value)","RRs r, RR_MX v","r.Cid = $Cid AND r.RRid = v.RRid");
        } elsif ($t_type eq "HINFO") {
            @select_stm = ("r.RRid,r.record,r.TTL,CONCAT_WS(' ',v.value1,v.value2)","RRs r, RR_HINFO v","r.Cid = $Cid AND r.RRid = v.RRid");
        } elsif ($t_type eq "PTR") {
            # not supported, don't think we'll need/want it
            next;
        } else {
            # CNAME, NS, or TXT  or AAAA
            @select_stm = ("r.RRid,r.record,r.TTL,v.value","RRs r, RR_$t_type v","r.Cid = $Cid AND r.RRid = v.RRid");
        }
        my $getrecords = IteratedSQLSelect(@select_stm);
        while (my ($RRid,$record,$rTTL,@value) = $getrecords->fetchrow_array)
        {
            if (($t_type eq 'HINFO') ||  ($t_type eq 'TXT'))
            {   # quote values, escape quotes first
                foreach (@value)
                {   # quote values, escape quotes first
                    s/[\n\r]+//g;
                    s/\"/\\"/g;
                    $_ = '"' . $_ . '"';
                }
            }
            my $value = join(' ',@value);
            $rTTL = 900 if ($rTTL < 900); # no less than 1hr
            $rTTL = 15811200 if ($rTTL > 15811200); # no more than 6month
            $dbfile_data .= "$record\t$rTTL\tIN\t$t_type\t$value\n";
        }
        $getrecords->finish;
    }

    return $dbfile_data;
}


sub bad_ipv6_addr
{
    my $ip = shift;

    $ip =~ s/\s+//g; # get rid of spaces, we don't care about them

    if ( length($ip) > 39 )
    {
        return "Too many characters in address";
    }

    unless ( $ip =~ /[a-fA-F0-9]*[a-fA-F1-9][a-fA-F0-9]*::?[a-fA-F0-9]*[a-fA-F1-9][a-fA-F0-9]*/ )
    {
        return "Address doesn't contain enough segments";
    }

    if ( (my @v = $ip =~ m/(:)/g) > 7)
    {
        return "Address has over 7 colons";
    }

    if ( (my @v = $ip =~ m/(:)/g) < 2)
    {
        return "Address has less than 2 colons";
    }

    if ( $ip =~ /:::/ )
    {
        return "Address has more than 2 colons in a row";
    }

    if ( $ip =~ /::.+::/ )
    {
        return "Double colon appears more than once in address";
    }

    if ( $ip =~ /[^:]{5,}/ )
    {
        return "Address has too many characters in one of it's segments";
    }

    unless ( $ip =~ /^[a-fA-F0-9:]+$/ )
    {
        return "Address contains invalid characters. Valid characters are: 0123456789abcdef:";
    }

    unless ( ((my @octets1 = split(/:+/,$ip)) >= 8) || (((my @octets2 = split(/:+/,$ip)) < 8) && ($ip =~ /::/)) )
    {
        return "Address has no ::, yet has less than 8 segments";
    }

    return;
}

sub send_mail
{
    my %mail = @_;
    my $smtp = Net::SMTP->new($smtphost);
    $smtp->mail($mail{from});
    $smtp->to($mail{to});
    $smtp->data();
    $smtp->datasend("To: $mail{to}\n");
    $smtp->datasend("From: $mail{from}\n");
    $smtp->datasend("Subject: $mail{subject}\n");
    $smtp->datasend("\n");
    $smtp->datasend($mail{msg});
    $smtp->datasend("\n");
    $smtp->dataend();
    $smtp->quit;
}

sub send_domain_delete
{
    my ($Cid,$uid) = @_;
    # will send message to master pdsysd.pl daemon to remove zone.
    # if successful, will remove from database

    my ($ownerid,$zone,$tld,$serial,$refresh,$retry,$expire,$ttl,$master,$admin_email) = SQLSelect(
        "c.ownerid,c.zone,c.tld,c.serial,c.refresh,c.retry,c.expire,c.TTL,c.master,c.admin_email",
        "conf c",
        "c.Cid = $Cid"
        );

    # fail now if we didn't find the zone
    return 0 unless $zone;

    my $login = SQLSelect("login","logins","uid = $uid");

    # send query to primary name server
    my $sock = new IO::Socket::INET (
        LocalAddr   => $cfg->{'daemon'}->{'webserver_addr'} || '',
        PeerAddr    => $cfg->{'daemon_master'}->{'addr'},
        PeerPort    => $cfg->{'daemon_master'}->{'port'} || 5201,
        Proto       => 'tcp'
        );

    return 0 unless $sock;

    my $query = encrypt( ('remove',"$zone.$tld",$Cid,0) );
    print $sock $query;
    close($sock);
    # clean up old shit
    my $get_records = IteratedSQLSelect("RRid,type","RRs","Cid = $Cid");
    while(my ($rrid,$rrtype) = $get_records->fetchrow_array)
    {
        SQLDelete("RR_$rrtype","RRid = $rrid");
    }
    $get_records->finish;
    SQLDelete("RRs","Cid = $Cid");
    SQLDelete("conf","Cid = $Cid");
    SQLDelete('pending_data',"Cid = $Cid"); # notifications

    # log it
    SQLInsert("log",
        ['Lid','login','uid','ownerid','action','zone','tld','remote_ip','oldvalues','timestamp'],
        ['NULL',$login,$uid,$ownerid,'domain_delete',$zone,$tld,$ENV{REMOTE_ADDR},"Cid=$Cid ownerid=$ownerid master=$master admin_email=$admin_email",'NULL'] );

    return 1;
}

1;
