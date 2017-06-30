#!/usr/bin/perl -w
# -*- mode: cperl ; mode: font-lock -*-   for emacs
use strict;
use DBI;

my $db = shift(@ARGV) || $ENV{DBNAME};

my $genspec = {
    db   => $db,
    host => $ENV{DBHOST},
    port => $ENV{DBPOR},
    user => $ENV{DBUSER},
    pwd  => $ENV{DBPASS}
};

my $dbh = myconnect();
die unless ($dbh);

for my $table ( sort $dbh->tables ) {
    print "\n##### $table\n";
    foreach my $row ( select_hashref( $dbh, "SELECT * FROM $table" ) ) {
        print join( "\t",
            map { $_ . ":" . $row->{$_} } sort keys %{$row}
        ) . "\n";
    }
    print "\n";
}
$dbh->disconnect();

#############################################################

sub select_hashref {
    my ( $dbh, $sql ) = @_;
    my @list;
    my $sth = $dbh->prepare($sql);
    $sth->execute;
    while ( my $row = $sth->fetchrow_hashref ) {
        push @list, $row;
    }
    return @list;
}

sub myconnect {
    my $moreopts = shift;
    my $opts     = {
        AutoCommit => 1,
        RaiseError => 1,
        PrintError => 1,
    };

    if ($moreopts) {
        map { $opts->{$_} = $moreopts->{$_} } keys %{$moreopts};
    }

    my $dbh = undef;
    eval {
        $dbh = DBI->connect(
            "DBI:mysql:database=$genspec->{db};host=$genspec->{host};mysql_socket=/tmp/mysql.sock",
            $genspec->{user}, $genspec->{pwd}, $opts
        );
    };

    return $dbh;
}

1;

#
# This file is part of LetsMT! Resource Repository.
#
# LetsMT! Resource Repository is free software: you can redistribute it
# and/or modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# LetsMT! Resource Repository is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with LetsMT! Resource Repository.  If not, see
# <http://www.gnu.org/licenses/>.
#