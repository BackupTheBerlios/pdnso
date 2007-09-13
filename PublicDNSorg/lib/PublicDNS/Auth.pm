package PublicDNS::Auth;
# ex: set tabstop=4 expandtab smarttab softtabstop=4 shiftwidth=4:

# $Source: /home/xubuntu/berlios_backup/github/tmp-cvs/pdnso/Repository/PublicDNSorg/lib/PublicDNS/Auth.pm,v $
# $Revision: 1.1 $
# $Date: 2007/09/13 05:53:04 $
# $Author: unrtst $

=head1 NAME

PublicDNS::Auth - Public-DNS.org authentication library.

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

# auth.pm
#
# login
#   new login:
#       my ($returnstatus,$login) = &login($login,$password);
#   renew login:
#       my ($returnstatus,$login) = &login;
#       (if login/password  are null, it'll try this method)
#   return statuses:
#       1   => good authentication
#       0   => failed authentication
#       -1  => login expired, needs to reauthenticate
# logout
#   just clears their session info (if ticket is valid).
#
# add_user
#   doesn't do any checks, just adds the user if it can
#
# cleanup
#   takes care of left over sessions...needs to be called from cron
#   once in a while to cleanup leftover shit.
#
# load_cgi_variables
#   loads cgi vars into the Q namespace

use strict;
use Net::SMTP;
use Digest::MD5 ();
use CGI qw(:standard);
use PublicDNS::Config;
use PublicDNS::DBlib;
use PublicDNS::Utils;

my $cfg = PublicDNS::Config::load_cfg() or die "Unable to load config file.";

use vars qw($tmpl_dir);
$tmpl_dir = $cfg->{'system'}->{'tmpl_dir'};

my $smtphost        = $cfg->{'system'}->{'smtphost'}      || 'localhost';
my $cookie_domain   = $cfg->{'system'}->{'cookie_domain'} || '';
# browser cookie expiration time
my $expire_seconds  = $cfg->{'system'}->{'cookie_expire_secs'}  || 60*60;    # cfg, or one hour
# Any session ticket that hasn't been updated in this long is deleted
my $cleanup_seconds = $cfg->{'system'}->{'cookie_destroy_secs'} || 60*60*12; # cfg or 12 hours

BEGIN {
    require Exporter;
    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS %I);
    $VERSION = "1.0";
    @ISA = 'Exporter',
    @EXPORT_OK = qw(login logout cleanup load_cgi_variables add_pending_user);
    @EXPORT = qw($tmpl_dir);
}

sub add_pending_user
{
    my ($login,$passwd) = @_;
    if ($login && $passwd)
    {
        my $exists = SQLSelect("login","logins","login = " . SQLQuote($login));
        return 0 if $exists;
        my $crypt_passwd = &_getcrypt($passwd);
        my $sqlnow = SQLSelect('NOW()');
        my $pkey = &make_rand_key;
        my $olduid = SQLSelect("max(uid)","logins_pending");
        SQLInsert('logins_pending',['uid','login','passwd','plain_passwd','signup','PKey'],["NULL",$login,$crypt_passwd,$passwd,$sqlnow,$pkey]);
        my $newuid = SQLSelect("max(uid)","logins_pending");
        return 0 unless ($newuid > $olduid);

        return $pkey;
    } else {
        return 0;
    }
}

sub add_user
{
    my ($login,$passwd) = @_;
    if ($login && $passwd)
    {
        my $exists = SQLSelect("login","logins","login = " . SQLQuote($login));
        return 0 if $exists;
        my $crypt_passwd = &_getcrypt($passwd);
        my $oldownerid = SQLSelect('max(ownerid)','logins');
        my $ownerid = $oldownerid + 1;
        my $olduid = SQLSelect("max(uid)","logins");
        SQLInsert("logins",["uid","ownerid","login","passwd"],["NULL",$ownerid,$login,$crypt_passwd]);
        my $newuid = SQLSelect("max(uid)","logins");
        my $newownerid = SQLSelect('max(ownerid)','logins');
        if ($newownerid <= $oldownerid)
        {
            SQLDelete('logins',"uid = $newuid") if ($newuid > $olduid);
            return 0;
        }
        return 0 if ($newuid <= $olduid);

        return $newuid;
    } else {
        return 0;
    }
}

sub cleanup
{
    my $cleanup_point = time() - $cleanup_seconds;
    SQLDelete("sessions","point < $cleanup_point");
}

sub login
{
    my $cgi = new CGI;
    my ($login,$passwd) = @_;

    my $remote_address = $ENV{REMOTE_ADDR};

    if ($login && $passwd)
    {   # if neither are null, they're trying to login.
        my ($uid,$local_passwd,$loginclass) = SQLSelect("uid,passwd,loginclass","logins","disabled != '1' AND login = " . SQLQuote($login));
        return (0,$login) unless $uid; # invalid login (user doesn't exist)

        my $crypt_passwd = &_getcrypt($passwd);
        if ($crypt_passwd eq $local_passwd)
        {
            # they're authenticated... need to update local session, set cookie ticket for them, and return "1" for logged in
            my $new_ticket = &_ticket;
            my $point = time;
            &_set_session($login,$remote_address,$new_ticket,$point);
            return (1,$login,$uid,$loginclass);
        } else {
            return (0,$login); # invalid login (passwd doesn't match)
        }
    }

    my $remote_login = $cgi->cookie('login');
    my $remote_ticket = $cgi->cookie('ticket');
    if ($remote_login && $remote_ticket)
    {   # they've logged in before (or are spoofing)
        my ($local_ticket,$local_point) = SQLSelect(
            "ticket,point",
            "sessions",
            "login = " . SQLQuote($remote_login) .
            " AND address = " . SQLQuote($remote_address)
            );
        my $point = time;
        if ($remote_ticket eq $local_ticket)
        {
            if ($local_point > ($point - $expire_seconds))
            {   # valid ticket, continue sesson
                # keep using existing ticket, update point on it
                # set remote cookie's (so they don't time out)
                # return logged in signal
                my $point = time;
                &_set_session($remote_login,$remote_address,$local_ticket,$point);
                my ($uid,$loginclass) = SQLSelect("uid,loginclass","logins","login = " . SQLQuote($remote_login));
                return (1,$remote_login,$uid,$loginclass);
            } else {
                # login has expired
                return (-1,$remote_login); #login expired
            }
        } else {
            # invalid ticket (username cookie matched, ticket cookie didn't)
            return (0,$remote_login); # invalid login
        }
    } else {
        # didn't try to login, and no cookies set
        return (0,0);
    }
}

sub logout
{
    my $cgi = new CGI;
    my $remote_login = $cgi->cookie('login');
    my $remote_address = $ENV{REMOTE_ADDR};
    if ($remote_login && $remote_address)
    {
        &_set_session($remote_login,$remote_address,'*',0);
    }
}

sub load_cgi_variables
{
    my $variables = new CGI;
    $variables->import_names('Q');
}

sub _set_cookie
{
    my ($login,$ticket,$point) = @_;
    my ($login_cookie,$ticket_cookie);

    my $base_cookie = '; domain=' . $cookie_domain;
    if ($point == 0)
    {   # if they hit logout, then try to expire their local cookie
        $base_cookie .= '; max-age=0';
    } else {
        $base_cookie .= '; max-age=' . $expire_seconds;
    }
    $base_cookie .= '; path=/';
    $base_cookie .= '; version=1';

    print 'Set-Cookie: login=' . $login . $base_cookie . "\n";
    print 'Set-Cookie: ticket=' . $ticket . $base_cookie . "\n";
}

sub _set_session
{
    my ($login,$address,$ticket,$point) = @_;

    &_set_cookie($login,$ticket,$point);

    # set local session
    my ($local_ticket) = SQLSelect(
        "ticket",
        "sessions",
        "login = " . SQLQuote($login) .
        " AND address = " . SQLQuote($address)
        );
    if ($local_ticket)
    {   # a session has already been stored for this user/addy
        SQLUpdate("sessions",["ticket","point"],[$ticket,$point],
            "login = " . SQLQuote($login) .
            " AND address = " . SQLQuote($address)
            );
    } else {
        # set a new local session
        SQLInsert("sessions",
            ["login","address","ticket","point"],
            [$login,$address,$ticket,$point]
            );
    }
}

sub _ticket
{
    my $length = 128;
    my $ticket;
    while($length-- > 0)
    {
        $ticket .= chr(rand(256));
    }
    return Digest::MD5::md5_hex($ticket);
}

sub _getcrypt
{
    my $pass = shift;
    return Digest::MD5::md5($pass);
}

1;
