package PublicDNS::DBlib;
# ex: set tabstop=4 expandtab smarttab softtabstop=4 shiftwidth=4:

=head1 NAME

PublicDNS::DBlib - Public-DNS.org DBI abstraction library.

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

# $Source: /home/xubuntu/berlios_backup/github/tmp-cvs/pdnso/Repository/PublicDNSorg/lib/PublicDNS/DBlib.pm,v $
# $Revision: 1.1 $
# $Date: 2007/09/13 05:53:04 $
# $Author: unrtst $


#############################################
# perl module to make sql operations easier #
#############################################

use strict;
use DBI;
use PublicDNS::Config;

my $mydbh = &SQLConnect;

BEGIN {

    require Exporter;
    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS %I $CRLF);
    $VERSION = '1.0';
    @ISA = 'Exporter';
    @EXPORT = qw(SQLConnect IteratedSQLSelect SQLSelect SQLSelectAll SQLSelect_hashref SQLInsert SQLUpdate SQLDelete SQLQuote);
    $CRLF = "\015\012";
    # SQLConnect is also available via full package naming:
    # PDlib::SQLConnect
    # it shouldn't normally be needed in any of our scripts.
    # SQLQuote shouldn't be needed either, except on quoting values for
    # where statements, so we're still exporting it to encourage quoting
    # of values in the were statements.
};

sub SQLConnect
{
    my ($pkg,$file,$line) = caller;

    # config module handles caching, so just call load every time incase it's changed.
    my $cfg = PublicDNS::Config::load_cfg() or die "Unable to load config file.";
    my $database = $cfg->{db_connection}->{database} || 'dns';
    my $dsn      = $cfg->{db_connection}->{dsn}      || 'dbi:mysql:host=localhost';
    my $user     = $cfg->{db_connection}->{user}     || '';
    my $password = $cfg->{db_connection}->{password} || '';

    my $mydbh = DBI->connect( $dsn, $user, $password,
                { PrintError => 1, RaiseError => 0, AutoCommit => 1 } )
        or die "Can't connect to dbase $database, line $line in file $file in package $pkg: $DBI::errstr\n";
    if ($database)
    {
        $mydbh->do("use $database")
            or die "Can't connect to dbase $database, line $line in file $file in package $pkg: $DBI::errstr\n";
    }

    return $mydbh;
}

sub IteratedSQLSelect
{

    #######################################################
    #######################################################
    ##
    ## This will allow you to select a lot of stuff at once
    ## usage should be self explanitory i hope =]
    ##

    my($select, $from, $where, $other) = @_;

    # make sure connection is still up
    &_check_active_connection();

    my $query = "SELECT $select ";
    $query .= "   FROM $from " if $from;
    $query .= "  WHERE $where " if $where;
    $query .= "        $other" if $other;

    my $handle = $mydbh->prepare($query);

    # If we can execute a statement then do it and send back the handle

    return $handle if ($handle->execute);

    # else we can finish things up and close the dbh
    my ($pkg,$file,$line) = caller;
    warn("Unable to execute handle at line $line in file $file package $pkg\n");
    $handle->finish;
    return;
}


sub SQLSelect_hashref
{
    ####################################################
    ####################################################
    ##
    ## Useful SQL Select wrapper to cut down on code
    ## in our friendly main scripts

    my($select, $from, $where, $other) = @_;

    # make sure connection is still up
    &_check_active_connection();

    my $query = "SELECT $select ";
    $query .= "FROM $from " if $from;
    $query .= "WHERE $where " if $where;
    $query .= "$other" if $other;

    my $handle = $mydbh->prepare($query);

    unless ($handle->execute)
    {
        my ($pkg,$file,$line) = caller;
        warn("Unable to execute handle at line $line in file $file package $pkg\n");
        return;
    }
    my $hashref = $handle->fetchrow_hashref;
    $handle->finish;

    return $hashref;
}

sub SQLSelect
{

    ####################################################
    ####################################################
    ##
    ## Useful SQL Select wrapper to cut down on code
    ## in our friendly main scripts


    my($select, $from, $where, $other) = @_;

    # make sure connection is still up
    &_check_active_connection();

    my $query = "SELECT $select ";
    $query .= "FROM $from " if $from;
    $query .= "WHERE $where " if $where;
    $query .= "$other" if $other;

    my $handle = $mydbh->prepare($query);

    unless ($handle->execute)
    {
        my ($pkg,$file,$line) = caller;
        warn("Unable to execute handle at line $line in file $file package $pkg\n");
        return;
    }
    my @array = $handle->fetchrow_array;
    $handle->finish;

    # return entire array if they're asking for an array,
    # otherwise return the first element
    return wantarray ? @array : $array[0];
}

sub SQLSelectAll
{

    ####################################################
    ####################################################
    ##
    ## Useful SQL Select wrapper to cut down on code
    ## in our friendly main scripts
    ##
    ## returns an array referance of all rows returns, containing
    ## an array referance of columns returned for each row


    my($select, $from, $where, $other) = @_;

    # make sure connection is still up
    &_check_active_connection();

    my $query = "SELECT $select ";
    $query .= "FROM $from " if $from;
    $query .= "WHERE $where " if $where;
    $query .= "$other" if $other;

    my $alldata = $mydbh->selectall_arrayref($query);
    if ($alldata)
    {
        return $alldata
    } else {
        my ($pkg,$file,$line) = caller;
        warn("Unable to execute handle at line $line in file $file package $pkg\n");
        return; # if there was an error, return nothing
    }
}

sub SQLInsert
{
    my ($pkg,$file,$line) = caller;
    ####################################################
    ####################################################
    ##
    ## Useful SQL Insert wrapper to cut down on code
    ## in our friendly main scripts
    ##
    ## Usage: SQLInsert($tablename,$fields_array_ref,$values_array_ref);

    my($table, $fields, $values) = @_;

    # make sure connection is still up
    &_check_active_connection();

    return unless ($table &&
                   (ref $fields eq "ARRAY") &&
                   (ref $values eq "ARRAY") &&
                   (@$fields == @$values)
                  );

    my $f_list = join(', ',@$fields);
    my ($v_list,@v_list);
    foreach(@$values)
    {
        if (/^NULL$/i)
        {   # make sure null's don't get quoted
            $v_list .= "NULL,";
        } else {
            $v_list .= "?,";
            push(@v_list,$_);
        }
    }
    chop($v_list); # remove last comma
    my $handle = $mydbh->prepare("INSERT INTO $table ($f_list) VALUES ($v_list)");
    if ($handle->execute(@v_list))
    {   # will auto-quote stuff this way.
        $handle->finish;
        # return 1 (success) if they want a return value, or just return.
        return defined(wantarray()) ? (1) : "";
    } else {
        # couldn't execute it.
        warn("Unable to execute insert handle at line $line in file $file package $pkg\n");
        return;
    }
}

sub SQLUpdate
{
    my ($pkg,$file,$line) = caller;

    ####################################################
    ####################################################
    ##
    ## Useful SQL Update wrapper to cut down on code
    ## in our friendly main scripts
    ##
    ## Usage: SQLUpdate($tablename,$fields_array_ref,$values_array_ref,$where_statement);

    my($table, $fields, $values, $where) = @_;

    # make sure connection is still up
    &_check_active_connection();

    # they must give us everything. UPDATE's without $where are valid SQL, but
    # I see no reason we should have them called from any script using this
    # sql wrapper. So we make sure they give us some where statement,
    # and they can pass "$where=1" if they really know what they're doing.
    return unless ($table &&
                   (ref($fields) eq "ARRAY") &&
                   (ref($values) eq "ARRAY") &&
                   (@$fields == @$values) &&
                   $where
                  );

    my $query = "UPDATE $table SET " . join(' = ? ,',@$fields);
    $query .= ' = ? ';

    $query .= " WHERE $where";

    foreach(@$values) { if (/^NULL$/i) { $_ = undef; } }
    my $handle = $mydbh->prepare($query);
    if ($handle->execute(@$values))
    {   # will auto-quote stuff this way.
        $handle->finish;
        # return 1 (success) if they want a return value, or just return.
        return defined(wantarray()) ? (1) : "";
    } else {
        # couldn't execute it.
        warn("Unable to execute update handle at line $line in file $file package $pkg\n");
        return;
    }
}

sub SQLDelete
{
    ####################################################
    ####################################################
    ##
    ## Useful SQLDelete wrapper to cut down on code
    ## in our friendly main scripts

    my($table,$where) = @_;

    # make sure connection is still up
    &_check_active_connection();

    if ($table && $where)
    {
        my $return_value = $mydbh->do("DELETE FROM $table WHERE $where");
        # return $return_value if they want a return value, or just return.
        return defined(wantarray()) ? ($return_value) : "";
    } else {
        return;
    }
}

sub SQLQuote
{
    ## THIS SHOULDN'T BE NEEDED EXCEPT A FEW CASES (where statements)
    ## MOST FUNCTIONS NEEDING QUOTING (inserts, updates)
    ## WILL DO QUOTING THEMSELVES

    ####################################################
    ####################################################
    ##
    ## Useful for quoting text fields, since we don't
    ## actually connect to DBI in the main scripts anymore
    ## it's needed
    ##
    ## Usage:
    ##  my @newvalues = SQLQuote(@values);
    ##  my $firstquotedvalue = $newvalues[0];
    ##  foreach (@newvalues) {
    ##      # do something
    ##  }

    # make sure connection is still up
    &_check_active_connection();

    my(@toreturn);
    foreach my $toquote (@_)
    {
        my $temp = $mydbh->quote($toquote);
        push(@toreturn,$temp);
    }
    # return entire array if they're asking for an array,
    # otherwise return the first element
    return wantarray ? @toreturn : $toreturn[0];
}

sub _check_active_connection
{
    my $rc = $mydbh->ping;
    unless ($rc)
    {   # we're not connected anymore, something died.
        $mydbh = &SQLConnect;
    }
    # we could loop until ok, or return some error code if we're still
    # not connected, but I'm just hoping this fixes things. We've been getting:
#DBD::mysql::st execute failed: MySQL server has gone away at /usr/local/apache/public-dns.purifieddata.net/lib/PDlib_dns.pm line 64.
#Unable to execute handle at line 87 in file /usr/local/apache/public-dns.purifieddata.net/lib/utils_dns.pm package utils_dns
#[Tue Aug 19 22:20:07 2003] [error] Can't call method "fetchrow_array" on an undefined value at /usr/local/apache/public-dns.purifieddata.net/lib/utils_dns.pm line 88.
}


1;
