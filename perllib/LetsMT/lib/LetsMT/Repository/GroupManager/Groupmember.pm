package LetsMT::Repository::GroupManager::Groupmember;

=head1 NAME

LetsMT::Repository::GroupManager::Groupmember - persistent object class for LetsMT's GroupManager

=cut

use strict;
use parent 'LetsMT::Repository::Persist';

use Log::Log4perl qw(get_logger :levels);
use LetsMT::Repository::Err;

my %persist_def = (
    fields => {
        user => { type => 'varchar(128) NOT NULL', prim => 1 },
        grp  => { type => 'varchar(128) NOT NULL', prim => 1 }
    }
);

my @quote_attrs    = ( 'user', 'grp' );
my @nonquote_attrs = ();
my @attrs          = ( @quote_attrs, @nonquote_attrs );

#####################################################
#### PUBLIC CLASS METHODS ###########################
#####################################################

=head1 CONSTRUCTOR

 new($class, $user, $grp)

Tries to create a new object. Fails if it already exists.

Returns: a Groupmember object

=cut

sub new {
    my ( $class, $user, $grp ) = @_;
    my $self = $class->SUPER::new();

    map { $self->{$_} = $persist_def{$_} } keys %persist_def;

    eval { $self->SUPER::initialize(); };

    if ($@) { raise( 7, $@ . "groupmember $user $grp", 'error' ) }

    if ($grp) {
        raise( 4, "groupmember $grp" )
            unless $self->init_instance(
            qq{user = '$user' AND grp = '$grp'},
            map { $_ => eval '$' . $_ } (@attrs)
            );
    }

    return $self;
}


=head1 METHODS

=head2 C<get_idquery>

 $gm->get_idquery ($user, $grp)

Returns: an SQL-query to be used by retrieve()

=cut

sub get_idquery {
    my ( $user, $grp ) = @_;

    return "user = '$user' AND grp = '$grp'";
}


=head2 C<get_idquery_users_in_group>

 $string = $gm->get_idquery_users_in_group ($grp)

Returns: an SQL-query to be used by retrieve()

=cut

sub get_idquery_users_in_group {
    my ($grp) = @_;

    return "grp = '$grp'";
}


=head2 C<get_idquery_groups_for_user>

 $string = $gm->get_idquery_groups_for_user ($user)

Returns: an SQL-query to be used by retrieve()

=cut

sub get_idquery_groups_for_user {
    my ($user) = @_;

    return "user = '$user'";
}


=head2 C<drop_table>

Drops the Groupmember table.

Returns: nothing

=cut

sub drop_table {
    my $obj = new LetsMT::Repository::GroupManager::Groupmember();
    $obj->SUPER::drop_table();
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