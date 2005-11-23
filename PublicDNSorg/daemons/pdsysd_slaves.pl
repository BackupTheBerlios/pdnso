#!/usr/bin/perl
# ex: set tabstop=4 expandtab smarttab softtabstop=4 shiftwidth=4:

# $Source: /home/xubuntu/berlios_backup/github/tmp-cvs/pdnso/Repository/PublicDNSorg/daemons/pdsysd_slaves.pl,v $
# $Revision: 1.1 $
# $Date: 2005/11/23 03:42:57 $
# $Author: unrtst $

=head1 NAME

pdsysd_slaves.pl - Public-DNS.org daemon to work with the BIND domain name system on the secondary (tertiary, etc) name servers.

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
use IO::Socket;
use Fcntl qw(:flock);
use PublicDNS::Config;
use PublicDNS::CryptWrapper;

$SIG{TERM} = 'error';
# ignore dead children (automatically reap the dead)
$SIG{CHLD} = 'IGNORE';

my $cfg = PublicDNS::Config::load_cfg() or die "Unable to load config file.";

my $listen_host = $cfg->{'daemon_slave'}->{'addr'} || '';
my $listen_port = $cfg->{'daemon_slave'}->{'port'} || '5202';
my $accept_host = $cfg->{'daemon_slave'}->{'accept_hostlist'};
my $eff_uid     = $cfg->{'daemon_slave'}->{'uid'};
my $eff_gid     = $cfg->{'daemon_slave'}->{'gid'};
my $pid_file    = $cfg->{'daemon_slave'}->{'pidfile'};

my $DEBUG=0;  # 1 for Debug info to be printed to console 0 for no debuging info

# Path to file, included by named.conf, to write our named.conf entries
my $includefile   = $cfg->{'daemon_slave'}->{'named_conf_includefile'};
# Path used by bind to find zone files (may be relative to bind root, sandbox, etc)
my $zonefile_path = $cfg->{'dns'}->{'zonefile_bindpath'};
# Path to where your log file is FULL PATH with file name
my $logpath       = $cfg->{'daemon_slave'}->{'logpath'};
# Path to where your rndc is
my $rndcpath      = $cfg->{'daemon_slave'}->{'rndcpath'};

my ($sec,$min,$hr,$day,$mon,$yr) = localtime; $yr+=1900; $mon++; $hr = "0$hr" if ($hr < 10);
$min = "0$min" if ($min < 10);
$sec = "0$sec" if ($sec < 10);
my $now = "$yr-$mon-$day $hr:$min:$sec";


# create pid file as root, then su to $eff_uid
open(PID,"> $pid_file") || warn "can't open $pid_file for writing\n";
    flock(PID, LOCK_EX);
    print PID $$;
    flock(PID, LOCK_UN);
close(PID);
# change effective uid
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

        my $maxsize = (1024*1024); # 1meg
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
        exit(0);
    } # else 'tis the parent process, goes back to accept()
} # End while loop

sub process
{
    my $buf = shift;
    my @pdinput = decrypt($buf);

    if ($DEBUG)
    {
        print "got into processing, input: @pdinput\n";
        foreach(@pdinput)
        {
            print "\t$_\n";
            foreach my $key ( keys %{$_} )
            {
                print "\t\t$key = $_->{$key}\n";
            }
        }
    }

    # get rid of any dups
    my %zonedups;
    my @pdinput2;
    foreach my $zoneref (@pdinput)
    {
        my $zone = $zoneref->{ZONE};
        next if ($zonedups{lc($zone)});
        # add to our hash of existing zones
        $zonedups{lc($zone)}++;
        push(@pdinput2,$zoneref);
    }

    open(NAMEDINCLUDE,">$includefile") || &die_error("can't open file $includefile: $!");
        flock(NAMEDINCLUDE, LOCK_EX);
        &error("UPDATED: $includefile");
        foreach my $zoneref (@pdinput2)
        {
            my $zone = $zoneref->{ZONE};
            my $master = $zoneref->{MASTER};
            if (&checkit($zone))
            {
                print NAMEDINCLUDE "zone \"$zone\" {
        type slave;
        file \"$zonefile_path/$zone\";
        allow-query { any; };
        masters {
            $master;
        };
    };\n\n";
            } else {
                # checkit prints the errors for us.
            }
        }
        flock(NAMEDINCLUDE, LOCK_UN);
    close(NAMEDINCLUDE);

    # sleep'ing here might leave room for DOS, cause processes could
    # build up, but we need some wait between when master dns calls its
    # reconfig, and when we call ours, or we the zone doesn't look like
    # it's on the master.
    sleep(10);
    system($rndcpath,'reconfig');

} #End process

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
            if ($DEBUG == '1') { print "Checking Vaild Domain: tld Good"; }
        }  # End if
        else {
            &error("Checking Vaild Domain: $domain Bad!"); return(0);
        } # End else
        if (length($domain) <= 3) { &error("Error: invalid domain name [$domain], Length"); return(0); }

    } #End if
    else {&error("Error: invalid domain name, Missing!"); return(0); }
    return 1;
} #End checkit

sub die_error
{
    my $err = shift;
    &error($err);
    exit(0);
}

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

    open(LOGFILE,">> $logpath") || die "can't open file $logpath: $!\n";
        flock(LOGFILE, LOCK_EX);
        print LOGFILE "$timenow $msg\n";
        flock(LOGFILE, LOCK_UN);
    close(LOGFILE);
    return 0;
} #End logit
