#!/usr/bin/perl
# ex: set tabstop=4 expandtab smarttab softtabstop=4 shiftwidth=4:

# $Source: /home/xubuntu/berlios_backup/github/tmp-cvs/pdnso/Repository/PublicDNSorg/daemons/pdsysd.pl,v $
# $Revision: 1.1 $
# $Date: 2005/11/23 03:42:57 $
# $Author: unrtst $

=head1 NAME

pdsysd.pl - Public-DNS.org daemon to work with the BIND domain name system on the primary name server.

=head1 NOTES

Please observer the following before running:

=over

=item * Make sure to configure the PublicDNS/Config.ini

=item * Make sure that you touch the log file

=item * Make sure that you have an include dir some where, where your named stuff lives

=item * Make sure that your passphrase is that same on both ends

=item * should be run as root, it will chown itself to $eff_uid before opening socket

=back

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
use Fcntl qw(:flock);
use IO::Socket;
use PublicDNS::Config;
use PublicDNS::CryptWrapper;

$SIG{TERM} = 'error';
# ignore dead children (automatically reap the dead)
$SIG{CHLD} = 'IGNORE';

my $cfg = PublicDNS::Config::load_cfg() or die "Unable to load config file.";

my $listen_host = $cfg->{'daemon_master'}->{'addr'} || '';
my $listen_port = $cfg->{'daemon_master'}->{'port'} || 5201;
my $accept_host = $cfg->{'daemon_master'}->{'accept_hostlist'};
my $eff_uid     = $cfg->{'daemon_master'}->{'uid'};
my $eff_gid     = $cfg->{'daemon_master'}->{'gid'};
my $pid_file    = $cfg->{'daemon_master'}->{'pidfile'};

my $master_host = $cfg->{'dns'}->{'master_ip'};
# build slave host -> port mapping (default port 5202; empty list for no slaves)
my %slaves;
foreach my $slave_key (grep /^slave_\d+_addr$/, keys %{$cfg->{'daemon_master'}})
{
    if ($slave_key =~ /^slave_(\d+)_addr$/)
    {
        my $number = $1;
        $slaves{$cfg->{'daemon_master'}->{'slave_'.$number.'_addr'}} = $cfg->{'daemon_master'}->{'slave_'.$number.'_port'} || 5202;
    }
}

my $DEBUG=0;  # 1 for Debug info to be printed to console 0 for no debuging info

my $zonepath               = $cfg->{'dns'}->{'zonefile_fullpath'}; # Path to where your zone files are
my $nonsandbox_zonepath    = $cfg->{'dns'}->{'zonefile_bindpath'}; # Path bind uses for where zone files are
my $confpath               = $cfg->{'dns'}->{'configfilemain_fullpath'}; # Path to where you named.conf file is FULL PATH with filename (never written to)
my $confincludepath        = $cfg->{'dns'}->{'configfileinc_fullpath'};  # Path to where you named.conf.include file is FULL PATH with filename (included by above file)
my $includepath            = $cfg->{'dns'}->{'includedir_fullpath'}; # Path to where your include dir is
my $nonsandbox_includepath = $cfg->{'dns'}->{'includedir_bindpath'}; # same as above, but relative to bind (non-sandboxed version)

my $logpath  = $cfg->{'daemon_master'}->{'logpath'};  # Path to where your log file is FULL PATH with file name
my $rndcpath = $cfg->{'daemon_master'}->{'rndcpath'}; # Path to where your rndc is

my ($sec,$min,$hr,$day,$mon,$yr) = localtime; $yr+=1900; $mon++;
my $now = sprintf('%04d-%02d-%02d %02d:%02d:%02d', $yr,$mon,$day,$hr,$min,$sec );
my $cmdnow = 0;


# create pid file as root, then su to $eff_uid
open(PID,"> $pid_file") || warn "can't open $pid_file for writing\n";
    flock(PID, LOCK_EX);
    print PID $$;
    flock(PID, LOCK_UN);
close(PID);
# change effective gid/uid (must change group first)
$) = $eff_gid;
$> = $eff_uid;

# log that we're starting up
&error("Starting up.");

$SIG{CHLD} = sub {wait ()};
my $main_sock = new IO::Socket::INET (
                    LocalHost   => $listen_host,
                    LocalPort   => $listen_port,
                    Listen      => 5,
                    Proto       => 'tcp',
                    Reuse       => 1
                    ); # End $main_sock
die "Couldn't create socket: $!\n" unless ($main_sock);
while (my $sock = $main_sock->accept()) {
    my $pid = fork();
    die "Cannot fork: $!" unless defined($pid);
    if ($pid == 0) {
        # Child process

        unless ( grep { $sock->peerhost() eq $_ } split(',', $accept_host) )
        {
            &error("Error: Attempt to connect from invalid host: " . $sock->peerhost() );
            close($sock);
            exit(0);
        }

        my $maxsize = (1024*64); # 64k
        my $file_too_big;
        my ($buffer,$data,$totalbytes);
        binmode $sock;
        while (my $bytesread = sysread($sock,$buffer,1024))
        {
            $data .= $buffer;
            $totalbytes += $bytesread;
            if ($totalbytes > $maxsize)
            {
                $file_too_big++;
                last;
            } # End if
        } # eND WHILE LOOP
        if ($file_too_big) {
            close($sock);
            &error("Error: Too Much data recieved"); exit(0);
        } else {
            close($sock);
            &process($data);
        } #End Else
    } # else 'tis the parent process, goes back to accept()
} # End while loop

sub process
{
    my $buf = shift;
    my @pdinput = decrypt($buf);
    my $set=shift(@pdinput);
    $cmdnow = pop(@pdinput);
    if    ($set eq 'system')    { &systemcall(\@pdinput); }
    elsif ($set eq 'add')       { &addcall(\@pdinput);    }
    elsif ($set eq 'addslave')  { my $master= pop(@pdinput); &addslavecall(\@pdinput,$master); }
    elsif ($set eq 'remove')    { &removecall(\@pdinput); }
    elsif ($set eq 'update')    { &updatecall(\@pdinput); }
    else  { &error("Error: Set doesn't match"); exit(0);}
} #End process

sub callslaves
{
    # this sub calls all our hosts in %slaves and sends them
    # the most recent list of domains->masters pulled from the named.conf

    my @slaves_list;
    opendir(INCLUDES,$includepath);
    while(my $file = readdir(INCLUDES))
    {
        next if (-d $includepath . "/$file"); # ignore subdir's
        next if ($file =~ /^\./); # ignore hidden files
        next if ($file !~ /^\d+-/); # all our auto-added zones begin w/ digits followed by a dash, skip if it doesn't.
        my ($zone,$master);
        open(ZONE,$includepath . "/$file") || next;
            flock(ZONE, LOCK_SH);
            while(<ZONE>)
            {
                if (/^zone\s+"(\S+)"\s/i)
                {
                    $zone = $1;
                } elsif (/^\s*masters\s+{\s*$/i) {
                    $master = <ZONE>;
                    $master =~ s/\s//g;
                    $master =~ s/;$//;
                    # } this is just to keep vi's % key working
                }
            }
            flock(ZONE, LOCK_UN);
        close(ZONE);
        $master = $master_host unless $master;
        push(@slaves_list,{ ZONE => $zone, MASTER => $master });
    }
    closedir(INCLUDES);

    foreach my $slave (keys %slaves)
    {
        &logit("Yelled at slave: $slave");
        my $call_sock = new IO::Socket::INET (
            LocalAddr   => $listen_host,
            PeerAddr    => $slave,
            PeerPort    => $slaves{$slave},
            Proto       => 'tcp'
            );
        if ($call_sock)
        {
            print $call_sock encrypt( @slaves_list );
            close($call_sock);
        }
    }
}

sub addcall
{
    my $pdinput = shift;
    my $domain = shift(@$pdinput);
    my $zoneid = shift(@$pdinput);
    &checkit($domain);

    if (&exists_in_conf($domain))
    {
        &error("Error: Domain all ready inuse");
        exit(0);
    }

    if ($DEBUG == '1') {print "\nAdd Domain: $domain ID $zoneid\n";} # End If
    &addinclude($domain,$zoneid);
    &addzoneincludefile($domain,$zoneid,'0');
    &addzonefile($pdinput,$domain,$zoneid);
    if ($cmdnow == '1')
    {
        system($rndcpath,'reconfig');
        &callslaves;
    } # End If
    if ($DEBUG == '1' && $cmdnow == '1') {print "\n$rndcpath reconfig\n"; } # ENd if
    &logit("ADDED: Domain: $domain ID $zoneid");
    exit(0);
} #End addcall

sub addslavecall
{
    my $pdinput = shift;
    my $master = shift;
    my $domain = shift(@$pdinput);
    my $zoneid = shift(@$pdinput);
    &checkit($domain);

    if (&exists_in_conf($domain))
    {
        &error("Error: Domain all ready inuse");
        exit(0);
    }

    if ($DEBUG == '1') {print "\nAdd Slave Domain: $domain ID $zoneid\n";} # End If
    &addinclude($domain,$zoneid);
    &addzoneincludefile($domain,$zoneid,'1',$master);
    if ($cmdnow == '1')
    {
        system($rndcpath,'reconfig');
        &callslaves;
    } # End IF
    if ($DEBUG == '1' && $cmdnow == '1') {print "\n$rndcpath reconfig\n"; } # End If
    &logit("ADDED SLAVE: Domain: $domain ID $zoneid");
    exit(0);
}
sub removecall
{
    my $pdinput = shift;
    my $domain = shift(@$pdinput);
    my $zoneid = shift(@$pdinput);
    &checkit($domain);
    unlink("$zonepath/$zoneid-$domain");
    unlink("$includepath/$zoneid-$domain");

    open(NAMED,"$confincludepath") || die "can't open file: $confincludepath $!\n";
        flock(NAMED, LOCK_SH);
        my @contents = <NAMED>;
        flock(NAMED, LOCK_UN);
    close(NAMED);

    open(NAMED,"> $confincludepath") || die "can't open file: $confincludepath $!\n";
        flock(NAMED, LOCK_SH);
        foreach (@contents)
        {
            next if
            (/^\s*include\s+"\Q$nonsandbox_includepath\E\/$zoneid-$domain";\s*$/);
            print NAMED $_;
        } #End foreach
        flock(NAMED, LOCK_UN);
    close(NAMED);
    if ($cmdnow == '1')
    {
        system($rndcpath,'reconfig');
        &callslaves;
    } # End If
    if ($cmdnow == '1' && $DEBUG == '1') { print "\n$rndcpath reconfig\n"; } # End If
    if ($DEBUG == '1') { print "REMOVING Domain: $domain ID: $zoneid\n"; } # End if
    &logit("REMOVED: Domain: $domain ID: $zoneid");
    exit(0);
} #End removeall

sub systemcall
{
    my $pdinput = shift;
    if ($DEBUG == '1') {print "\nSystem \n";} # End IF
    my $nextset = shift(@$pdinput);
    if ($nextset eq 'reload')
    {
        my $domain = shift(@$pdinput);
        if ($domain)
        {
            system($rndcpath,'reload',$domain);
            if ($DEBUG == '1') {print "$rndcpath reload $domain\n";}
        } #End if
        else
        {
            system($rndcpath,'reload');
            if ($DEBUG == '1') {print "$rndcpath reload\n";} # End if
        } #ENd else
    } #End if
    else
    {
        if ($nextset eq 'reconfig')
        {
            system($rndcpath,'reconfig');
            &callslaves;
            if ($DEBUG == '1') {print "$rndcpath reconfig";}
        } #End if
        else
        {
            &error("Error: NextSet [$nextset] doesn't match");
            exit(0);
        } #End else
    } #End else
    exit(0);
} #End Systemcall

sub updatecall
{
    my $pdinput = shift;
    my $domain = shift(@$pdinput);
    my $zoneid = shift(@$pdinput);
    &checkit($domain);

    unless (&exists_in_conf($domain))
    {
        &error("Error: Domain [$domain] doesn't match any valid domains");
        exit(0);
    }

    unlink("$zonepath/$zoneid-$domain");
    &addzonefile($pdinput,$domain,$zoneid);
    if ($cmdnow == '1') { system($rndcpath,'reload',$domain); } # End If
    if ($DEBUG == '1') {print "Updated Domain: $domain ID: $zoneid\n"; } # End if
    &logit("UPDATED: Domain: $domain ID: $zoneid");
    exit(0);
} #End updatecall

sub addinclude
{
    my $domain = shift;
    my $zoneid = shift;
    open(NAMED,">> $confincludepath") || die "can't open file: $confincludepath $!\n";
        flock(NAMED, LOCK_EX);
        print NAMED "include \"$nonsandbox_includepath/$zoneid-$domain\";\n";
        flock(NAMED, LOCK_UN);
    close(NAMED);
    if ($DEBUG == '1') {print "\nAdding Domain: $domain to named.conf\n"; } # End if
    return 0;
} #End addinclude

sub addzoneincludefile
{
    my $domain = shift;
    my $zoneid = shift;
    my $slave = shift;
    my $master = shift;
    if ($slave == '0')
    {
        open(INCLUDE,"> $includepath/$zoneid-$domain") || die "can't open file: $includepath/$zoneid-$domain";
            flock(INCLUDE, LOCK_EX);
            print INCLUDE "zone \"$domain\" {\n";
            print INCLUDE "     type master;\n";
            print INCLUDE "     file \"$nonsandbox_zonepath/" . $zoneid . "-" . $domain . "\";\n";
            print INCLUDE "     allow-query { any; };\n";
            print INCLUDE "};";
            flock(INCLUDE, LOCK_UN);
        close(INCLUDE);
        if ($DEBUG == '1') {print "\nAdding Domain Include File: $includepath/$zoneid-$domain"; } # End If
    } # End if
    else
    {
        open(INCLUDE,"> $includepath/$zoneid-$domain") || die "can't open file: $includepath/$zoneid-$domain";
            flock(INCLUDE, LOCK_EX);
            print INCLUDE "zone \"$domain\" {\n";
            print INCLUDE "     type slave;\n";
            print INCLUDE "     file \"$nonsandbox_zonepath/" . $zoneid . "-" . $domain . "\";\n";
            print INCLUDE "     allow-query { any; };\n";
            print INCLUDE "     masters {\n";
            print INCLUDE "         $master;\n";
            print INCLUDE "     };\n";
            print INCLUDE "};\n";
            flock(INCLUDE, LOCK_UN);
        close(INCLUDE);
        if ($DEBUG == '1') {print "\nAdding Domain Include File: $includepath/$zoneid-$domain"; } # End if
    } # End else
    return 0;
} #End addzoneincludefile

sub addzonefile
{
    my $pdinput = shift;
    my $domain = shift;
    my $zoneid = shift;
    open(ZONE,"> $zonepath/$zoneid-$domain") || die "can't open file: $zonepath/$zoneid-$domain";
        flock(ZONE, LOCK_EX);
        foreach(@$pdinput)
        {
            print ZONE $_;
        } #End foreach
        flock(ZONE, LOCK_UN);
    close(ZONE);
    if ($DEBUG == '1') {print "\nAdding Zone file for Domain: $domain ID $zoneid"; }
    return 0;
} #End addzonefile

sub checkit
{
    my $domain = shift;
    if ($domain)
    {
        my %tlds = (com => 1,net => 1,org => 1,us=> 1,to => 1,info => 1,tv => 1,
                ca => 1,cc => 1,edu => 1,gov => 1,it => 1,nu => 1,ws => 1);

        my $tld;
        if ($domain =~ /[A-Za-z0-9-]\.([A-Za-z0-9-]+)$/) { $tld = $1;} # End if
        else { $tld = 0; } # End else

# TODO: re-enable the full tld check... which will require us to have a full list of valid tlds (probably from the config file).
#       if ($tld && $tlds{$tld}) {
        if ($tld) {
            if ($DEBUG == '1') { print "Checking Vaild Domain: Good"; }
        }  # End if
        else {
            &error("Checking Vaild Domain: $domain Bad!"); exit(0);
        } # End else
        if (length($domain) <= 3) { &error("Error: invalid domain name, Length"); exit(0); }

    } #End if
    else {&error("Error: invalid domain name, Missing!"); exit(0); }
    return 0;
} #End checkit

sub error
{
    my $err = shift;
    if ($DEBUG == '1') {print "$err \n";}
    if ($err eq "TERM")
    { # sig trap
        $err = "TERM signal recieved, shutting down.";
        &logit($err);
        exit;
    }
    &logit($err);
    return 0;
} #End error

sub logit
{
    my $msg = shift;
    my ($sec,$min,$hr,$day,$mon,$yr) = localtime;
    $yr+=1900;
    $mon++;
    my $timenow = sprintf('%04d-%02d-%02d %02d:%02d:%02d', $yr,$mon,$day,$hr,$min,$sec );

    open(LOGFILE,">> $logpath") || die "can't open file: $!\n";
        flock(LOGFILE, LOCK_EX);
        print LOGFILE "$timenow $msg\n";
        flock(LOGFILE, LOCK_UN);
    close(LOGFILE);
    return 0;
} #End logit

sub exists_in_conf
{
    my $domain = shift;

    {
        open(NAMED,"$confpath") || die "can't open file: $confpath $!\n";
        flock(NAMED, LOCK_SH);
        my @contents = <NAMED>;
        flock(NAMED, LOCK_UN);
        close(NAMED);
        foreach(@contents)
        {
            if (/^\s*zone\s+"\Q$domain\E"/i)
            {
                return 1;
            } # End if
        } # End foreach
    }
    {
        open(NAMED,"$confincludepath") || die "can't open file: $confincludepath $!\n";
        flock(NAMED, LOCK_SH);
        my @contents = <NAMED>;
        flock(NAMED, LOCK_UN);
        close(NAMED);
        foreach(@contents)
        {
            if (/^\s*include\s+"\Q$nonsandbox_includepath\E\/\d+-\Q$domain\E";/i)
            {
                return 1;
            } # End if
        } # End foreach
    }

    return 0; # not in config
}
