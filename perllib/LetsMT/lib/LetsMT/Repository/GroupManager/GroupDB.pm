package LetsMT::Repository::GroupManager::GroupDB;

use strict;

use LetsMT;
use LetsMT::Repository::Err qw/ raise /;
use LetsMT::Repository::DB;

my $GroupDBFile = $ENV{LETSMTDISKROOT} . '/groups.tct';

sub new {
    my $class = shift;
    my %self  = shift;

    # use TokyoTyrant!
    if ( $LetsMT::RR_MANAGER_DBMS eq 'tt' ) {
        $self{DB} = new LetsMT::Repository::DB(
            -type => $LetsMT::RR_MANAGER_DBMS,
            -host => $LetsMT::TT_GROUP_HOST,
            -port => $LetsMT::TT_GROUP_PORT,
        );
    }

    # otherwise: use TokyoCabinet locally
    else {
        $self{DB} = new LetsMT::Repository::DB(
            -database => $GroupDBFile,
            -type     => $LetsMT::RR_MANAGER_DBMS,
        );
    }

    $self{DB}->open() || raise( 7, 'cannot open DB', 'error' );
    bless \%self, $class;
    return \%self;
}


# make sure that the database is closed

DESTROY {
    my $self = shift;
    $self->{DB}->close();
}


sub delete_all {
    my $self = shift;
    $self->{DB}->delete_all();
}


sub get {
    my $self = shift;
    return $self->{DB}->get(@_);
}


sub put {
    my $self = shift;
    return $self->{DB}->put(@_);
}


sub post {
    my $self = shift;
    return $self->{DB}->post(@_);
}


sub delete {
    my $self = shift;
    return $self->{DB}->delete(@_);
}


sub search {
    my $self = shift;
    return $self->{DB}->search(@_);
}


sub get_all_groups {
    my $self   = shift;
    my @groups = ();
    $self->{DB}->iter_start();
    while ( my $GroupName = $self->{DB}->get_next_key ) {
        push( @groups, $GroupName );
    }
    return @groups;
}


sub is_member {
    my $self = shift;
    my ( $user, $group ) = @_;
    my @members = $self->members($group);
    return 1 if ( grep ( $_ eq $user, @members ) );
    return 0;
}


sub members {
    my $self = shift;
    return [] if ( ref( $_[0] ) ne 'HASH' );
    return split( ',', $_[0]->{member} );
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