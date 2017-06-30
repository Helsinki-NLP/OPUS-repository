package LetsMT::Repository::StorageManager::MySQL::Branch;

=head1 NAME

LetsMT::Repository::StorageManager::MySQL::Branch - persistent object class for LetsMT's StorageManager

=cut

use strict;
use parent 'LetsMT::Repository::Persist';

use Log::Log4perl qw(get_logger :levels);
use LetsMT::Repository::Safesys;
use LetsMT::Repository::Err;


my %persist_def = (
    fields => {
        name       => { type => 'varchar(128) NOT NULL', prim => 1 },
        owner      => { type => 'varchar(64)  NOT NULL', prim => 1 },
        slot       => { type => 'varchar(128) NOT NULL', prim => 1 },
        grp        => { type => 'varchar(128) NOT NULL' },
        userread   => { type => 'INT NOT NULL DEFAULT 1' },
        userwrite  => { type => 'INT NOT NULL DEFAULT 1' },
        groupread  => { type => 'INT NOT NULL DEFAULT 1' },
        groupwrite => { type => 'INT NOT NULL DEFAULT 0' },
        otherread  => { type => 'INT NOT NULL DEFAULT 0' },
        otherwrite => { type => 'INT NOT NULL DEFAULT 0' },
        creat      => { type => 'DATETIME' },
        acces      => { type => 'DATETIME' },
        modif      => { type => 'DATETIME' }
    }
);

my @quote_attrs = ( 'name', 'owner', 'grp', 'slot' );
my @nonquote_attrs = (
    'userread',  'userwrite',  'groupread', 'groupwrite',
    'otherread', 'otherwrite', 'creat',     'acces',
    'modif'
);
my @attrs = ( @quote_attrs, @nonquote_attrs );


=head1 CONSTRUCTOR

 $manager = new LetsMT::Repository::StorageManager::Branch (
     $class, $repos, $name, $slot, $owner, $grp,
     $userread, $userwrite,
     $groupread, $groupwrite,
     $otherread, $otherwrite
 )

=cut

# TODO: why do we need $repos?

sub new {
    my ($class,     $repos,      $name,      $slot,
        $owner,     $grp,        $userread,  $userwrite,
        $groupread, $groupwrite, $otherread, $otherwrite
    ) = @_;
    my $creat = LetsMT::Repository::Safesys::time();
    my $acces = LetsMT::Repository::Safesys::time();
    my $modif = LetsMT::Repository::Safesys::time();
    my $self  = $class->SUPER::new();

    map { $self->{$_} = $persist_def{$_} } keys %persist_def;

    eval { $self->SUPER::initialize(); };

    if ($@) { raise( 7, $@ . "branch $repos/$owner" ) }

    if ($repos) {
        raise( 4, "branch $repos/$owner" )
            unless $self->init_instance(
            qq{name = '$name' AND owner = '$owner' AND slot = '$slot'},
            map { $_ => eval '$' . $_ } (@attrs) );
    }

    return $self;
}


=head1 METHODS

=head2 C<make_idquery>

 $sql = $manager->make_idquery (
     name           => $name,
     user           => $user,
     groups         => $groups,
     slot           => $slot,
     superuser_view => $superuser_view,
 )

Returns: an SQL query to be used by C<retrieve>.

=cut

#### Returns identification query

sub make_idquery {
    my $self   = shift;
    my %params = @_;
    map { $params{$_} = "" unless ( defined( $params{$_} ) ) }
        qw/ name user groups slot superuser_view /;
    my $qgroups = LetsMT::Repository::Safesys::sql_escape( $params{groups} );
    my $query   = "";
    unless ( $params{superuser_view} ) {
        $query
            .= "( (owner = '$params{user}' AND userread = 1 ) OR (grp IN ($qgroups) AND groupread = 1 ) OR ( otherread = 1 ) )";
    }

    if ( $params{slot} ) {
        $query = "slot = '$params{slot}' AND " . $query;
    }
    if ( $params{name} ) {
        $query = "name = '$params{name}' AND " . $query;
    }
    $query =~ s/\s+AND\s*$//;

    return $query;
}


=head2 C<may_write>

 $result = $manager->may_write ($user, $groups)

Checks whether this Branch may be written to by the effective user.

Returns: true or false

=cut

sub may_write {
    my ( $self, $user, $groups ) = @_;

    return
           ( $self->owner eq $user && $self->userwrite )
        || ( grep( /^$self->grp$/, @{$groups} ) && $self->groupwrite )
        || $self->otherwrite;
}


=head2 C<may_read>

 $result = $manager->may_read ($self, $user, $groups)

Checks whether this Branch may be read to by the effective user.

Returns: true or false

=cut

sub may_read {
    my ( $self, $user, $groups ) = @_;

    return
           ( $self->owner eq $user && $self->userread )
        || ( grep( /^$self->grp$/, @{$groups} ) && $self->groupread )
        || $self->otherread;
}


=head2 C<pp_perms>

 $string = $manager->pp_perms

Pretty-print the permission part of the data records.

Returns: pretty-printed string.

=cut

sub pp_perms {
    my $self  = shift;
    my $pp    = "";
    my @perms = (
        $self->userread,   $self->userwrite, $self->groupread,
        $self->groupwrite, $self->otherread, $self->otherwrite
    );

    for ( my $i = 0; $i < scalar(@perms); $i += 2 ) {
        $pp .= $perms[$i]       ? "r" : "-";
        $pp .= $perms[ $i + 1 ] ? "w" : "-";
    }

    return $pp;
}


=head1 CLASS METHOD

=head2 C<drop_table>

Drop the Branch table.

Returns: nothing

=cut

sub drop_table {
    my $branchobj = new LetsMT::Repository::StorageManager::MySQL::Branch();
    $branchobj->SUPER::drop_table();
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