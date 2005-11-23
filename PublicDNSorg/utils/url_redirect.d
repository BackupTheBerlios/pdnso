#!/usr/bin/perl
# ex: set tabstop=4 expandtab smarttab softtabstop=4 shiftwidth=4:

# $Source: /home/xubuntu/berlios_backup/github/tmp-cvs/pdnso/Repository/PublicDNSorg/utils/url_redirect.d,v $
# $Revision: 1.1 $
# $Date: 2005/11/23 03:42:57 $
# $Author: unrtst $

use strict;
use Fcntl qw(:flock);
use IO::Socket;
use PublicDNS::DBlib;
use FileHandle;
use PublicDNS::Config;
use Time::Local;

my $cfg = PublicDNS::Config::load_cfg() or die "Unable to load config file.";

my $DEBUG = 0;

my $listen_host = $cfg->{'url_redirector'}->{'listen_addr'} || '';
my $listen_port = $cfg->{'url_redirector'}->{'listen_port'} || 80;
my $pid_file    = $cfg->{'url_redirector'}->{'pidfile'}     || '/var/run/url_redirector.pid';
my $log_file    = $cfg->{'url_redirector'}->{'logfile'}     || '/var/log/url_redirector.log';
my @weekdays = (
    "",
    "Mon",
    "Tue",
    "Wed",
    "Thu",
    "Fri",
    "Sat",
    "Sun"
    );
my @months =(
    "",
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec"
    );

my $main_pid = $$;
open(PID,">$pid_file") or warn "can't open pid file $pid_file";
    flock(PID, LOCK_EX);
    print PID $main_pid;
    flock(PID, LOCK_UN);
close(PID);

my $log_fh = new FileHandle(">> $log_file") or
                 die "can't open log[$log_file] for writing";
flock($log_fh, LOCK_EX);
$log_fh->autoflush(1);
$log_fh->print("Starting up... " . scalar(localtime()) . "\n");

#END {
#   my $thispid = $$;
#   if (($thispid != 0) && ref($log_fh))
#   {   # log that we died (don't log child exit's)
#       $log_fh->print("Exiting... " . scalar(localtime()) . "\n");
#   }
#}

$SIG{CHLD} = sub {wait ()};
my $main_sock = new IO::Socket::INET (
                    LocalHost   => $listen_host,
                    LocalPort   => $listen_port,
                    Listen  => 5,
                    Proto   => 'tcp',
                    Reuse   => 1
                    ); # End $main_sock
die "Couldn't create socket: $!\n" unless ($main_sock);
while (my $sock = $main_sock->accept()) {
    my $pid = fork();
    unless (defined($pid))
    {
        $log_fh->print("Unable to fork() [" . scalar(localtime()) . "]: $!\n");
        close($sock);
        next;
        # die "Cannot fork: $!";
    }
    if ($pid == 0) {
        my $remote_ip = $sock->peerhost();

        my $get = <$sock>;
        warn $get if $DEBUG;

        # if it's a bad request, log and move on
        unless ($get)
        {
            &log($remote_ip,'NO_GET_PASSED_IN','','400');
            close($sock);
            exit(0);
        }
        # determine filename from GET/POST (error out if something else)
        my $file;
        if ($get =~ /^(GET|POST)\s+(\S+)/i)
        {
            $file = $1;
        } else {
            &log($remote_ip,"INVALID_GET_PASSED_IN:$get",'','400');
            close($sock);
            exit(0);
        }

        my $host;
        SOCKREAD: while(<$sock>)
        {
            warn $_ if $DEBUG;
            if ( (!$host) && /^Host:\s+(\S+)/i)
            {
                $host = lc($1);
            } elsif (/^\s*$/) {
                last SOCKREAD;
            }
        }

        # our db uses same type of host entries as our bind dns database (hostnames end in period)
        $host = $host . "." if ($host && ($host !~ /\.$/));

        my ($sec,$min,$hr,$day,$mon,$year) = localtime(time + (5*60*60)); # adjust to GMT
        $year += 1900; $mon++;
        my $formatted_time = sprintf('%02d:%02d:%02d', ($hr,$min,$sec));
        my $english_day = $weekdays[day_of_week($year,$mon,$day)];
        my $english_month = $months[$mon];

        my ($urid,$secure,$forwardto,$page,$cloak,$title,$keywords,$description);
        if ($host)
        {
            ($urid,$secure,$forwardto,$page,$cloak,$title,$keywords,$description) = SQLSelect("urid,secure,forwardto,page,cloak,title,keywords,description","urlredirect",'url = ' . SQLQuote($host) );
        }
        unless ($urid)
        {
            # forward to default page
            ($urid,$secure,$forwardto,$page,$cloak,$title,$keywords,$description) = SQLSelect("urid,secure,forwardto,page,cloak,title,keywords,description","urlredirect","url = 'default'" );
        }
        unless ($urid)
        {
            &log($remote_ip,"NO_URID:$get",$host,'400');
            close($sock);
            exit(0);
        }

        my $fw_location = $secure ? 'https://' : 'http://';
        $fw_location .= $forwardto;
        if ($page =~ /^\//)
        {
            $fw_location .= $page;
        } elsif ($page) { # they forgot to prepend a "/"
            $fw_location .= "/" . $page;
        } elsif ($file =~ /^\//) {
            $fw_location .= $file;
        } else {
            $fw_location .= "/" . $file;
        }

        &log($remote_ip,$get,$host,$cloak);

        warn "\nLocation: $fw_location\n---------\n" if $DEBUG;

        if ($cloak && $sock->peerhost() )
        {
            print $sock "HTTP/1.1 200 OK Found
Date: $english_day, $day $english_month $year $formatted_time GMT
Server: PDRedirect/1.2.79 (Unix)
Connection: close
Content-Type: text/html;

<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML 2.0//EN\">
<HTML><HEAD>
<TITLE>$title</TITLE>
<META NAME=\"description\" content=\"$description\">
<META NAME=\"keywords\" content=\"$keywords\">
<LINK REL=\"shortcut icon\" HREF=\"/favicon.ico\">
</HEAD>

<FRAMESET BORDER=0 ROWS=\"100\%,*\">
    <FRAME NAME=\"topframe\" SRC=\"$fw_location\">
</FRAMESET>
<NOFRAMES>
    <META HTTP-EQUIV=\"refresh\" CONTENT=\"0; URL=$fw_location\">
    <BODY><A HREF=\"$fw_location\">Click here to continue to $title</A><BR>
    <BR>
    Title: $title<BR>
    Description: $description<BR>
    Keywords: $keywords
    </BODY>
</NOFRAMES>
</HTML>

0
";
            close($sock);
        } elsif ($sock->peerhost() ) {
            print $sock "HTTP/1.1 302 Found
Date: $english_day, $day $english_month $year $formatted_time GMT
Server: PDRedirect/1.2.79 (Unix)
Location: $fw_location
Transfer-Encoding: chunked
Content-Type: text/html; charset=iso-8859-1

135
<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML 2.0//EN\">
<HTML><HEAD>
<TITLE>302 Found</TITLE>
</HEAD><BODY>
<H1>Found</H1>
The document has moved <A HREF=\"$fw_location\">here</A>.<P>
<HR>
<ADDRESS>PDRedirect/1.2.79 Server Server at $listen_host Port $listen_port</ADDRESS>
</BODY></HTML>

0
";
            close($sock);
        }
        exit(0);
    }
}

sub log
{
    my ($ip,$get,$host,$cloak) = @_;
    $get =~ s/[\n\r]$//g;
    my $response_code = ($cloak =~ /^\d\d\d$/) ? $cloak :
                         $cloak                ? 200    :
                                                 302    ;
    my ($sec,$min,$hr,$day,$mon,$year) = localtime();
    $year += 1900; $mon++;
    ($sec,$min,$hr,$day) = map { sprintf('%02d',$_) } ($sec,$min,$hr,$day);

    $log_fh->print("$ip - - [$day/$months[$mon]/$year:$hr:$min:$sec -0500] \"$get\" $response_code 0 \"-\" \"$host\"\n");
}

sub day_of_week
{
    my ($yyyy,$mm,$dd) = @_;
    $yyyy -= 1900 if ($yyyy > 1900);
    $mm--;
    my $weekday_index = 6;
    return (localtime(timelocal( 0, 0, 0, int($dd), int($mm), int($yyyy))))[$weekday_index];
}
