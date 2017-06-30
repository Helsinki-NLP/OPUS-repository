package LetsMT::Repository::StorageManager::MySQL::Slot;

=head1 NAME

LetsMT::Repository::StorageManager::MySQL::Slot - persistent object class for LetsMT's StorageManager

=cut

use strict;
use parent 'LetsMT::Repository::Persist';

use Log::Log4perl qw(get_logger :levels);

use LetsMT::Repository::Safesys;
use LetsMT::Repository::Err;


my %persist_def = (
    fields => {
        name      => { type => 'varchar(128) NOT NULL', prim => 1 },
        partition => { type => 'varchar(128) NOT NULL' },
        diskname  => { type => 'varchar(128) NOT NULL' },
        locked    => { type => 'INT NOT NULL DEFAULT 0' }
    }
);

my @quote_attrs    = ( 'name', 'partition', 'diskname' );
my @nonquote_attrs = ('locked');
my @attrs          = ( @quote_attrs, @nonquote_attrs );


=head1 CONSTRUCTOR

 $slot = new LetsMT::Repository::StorageManager::MySQL::Slot ($name, $partition)

=cut

sub new {
    my ($class,
        $name, $partition    ## optional
    ) = @_;
    my $locked = 0;
    my $online = 1;                      # assume this is true...
    my $self   = $class->SUPER::new();

    map { $self->{$_} = $persist_def{$_} } keys %persist_def;

    eval { $self->SUPER::initialize(); };

    if ($@) { raise( 7, $@ . "slot $name" ) }

    if ($name) {
        my $diskname = LetsMT::Repository::Safesys::safe_filesys_unique_name(
            "/" . $name
        );
        raise( 4, "slot $partition/$diskname" )
            unless $self->init_instance( qq{name = '$name'},
            map { $_ => eval '$' . $_ } (@attrs) );
    }

    return $self;
}


=head1 METHODS

=head2 C<make_idquery>

 $sql = $slot->make_idquery (name => name)

Returns: SQL query to be used in a C<retrieve>.

=cut

sub make_idquery {
    my $self = shift;

    my %params = @_;
    map { $params{$_} = "" unless ( defined( $params{$_} ) ) } qw/ name /;

    my $query = "";
    if ( $params{name} ) {
        $query = "name = '$params{name}'";
    }

    return $query;
}


=head2 C<may_write>

 $result = $slot->may_write ($user, $groups)

Checks whether this instance may be written to by the effective user.

# FIXME: this seems malplaced, is it even used? The subs in Branch is probably the right stuff.

Returns: true or false

=cut

sub may_write {
    my ( $self, $user, $groups ) = @_;

    return
           ( $self->branchowner eq $user && $self->userwrite )
        || ( grep( /^$self->grp$/, @{$groups} ) && $self->groupwrite )
        || $self->otherwrite;
}


=head2 C<is_locked>

 $slot->is_locked ($name)

# UNCHECKED, PROBABLY OBSOLETE, REMOVE

=cut

sub is_locked {
    my ( $self, $name ) = @_;
    return $self->locked;
}


=head2 C<set_lock>

 $slot->set_lock ($status)

# UNCHECKED, PROBABLY OBSOLETE, REMOVE

=cut

sub set_lock {
    my ( $self, $status ) = @_;
    $self->locked($status);
    $self->save;
}

# TODO: this is not compatible with the TC functionalities ...
# (but we're going to remove the mySQL mode anyway ....)
#
# always return default backend in mySQL mode
# (for simplicity here and because we're not going to use mySQL anymore)

sub type { return $ENV{VC_BACKEND}; }


=head1 CLASS METHOD

=head2 C<drop_table>

Drop the Slot table.

Returns: nothing

=cut

sub drop_table {
    my $obj = new LetsMT::Repository::StorageManager::MySQL::Slot();
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