package LetsMT::Repository::StorageManager::TC::Slot;

=head1 NAME

LetsMT::Repository::StorageManager::TC::Slot - persistent object class for LetsMT's StorageManager

=cut

use strict;
use parent 'LetsMT::Repository::StorageManager::TC';

use open qw(:std :utf8);

use LetsMT::Repository::MetaManager;
use LetsMT::Repository::StorageManager::Branch;
use LetsMT::Repository::GroupManager;

use Log::Log4perl qw(get_logger :levels);
use LetsMT::Repository::Safesys;
use LetsMT::Repository::Err;


my $DEFAULT_PARTITION = defined( $ENV{LETSMTDISKROOT} )
    ? $ENV{LETSMTDISKROOT}
    : "/tmp/fallbackdisk";


=head1 METHODS

=head2 C<make_instance>

=cut

sub make_instance {
    my $self = shift;
    my ( $name, $partition, $type ) = @_;

    if ($name) {
        my $metaDB = new LetsMT::Repository::MetaManager();
        $metaDB->open() || raise( 7, "cannot open meta database", 'error' );
        my $data = $metaDB->get($name);

        ## slot exists already! --> fail!
        raise( 4, "slot $partition/$name", 'error' ) if ( keys %{$data} );

        $self->{meta}->{name}         = $name;
        $self->{meta}->{partition}    = $partition if ($partition);
        $self->{meta}->{storage_type} = $type ? $type : $ENV{VC_BACKEND} ;

        ## initialize object
        $self->init_instance();

        # store meta-data
        $metaDB->post( $self->{meta}->{name}, $self->{meta} )
            || raise( 7, "cannot pots slot data ($name)", 'error' );

        $metaDB->close();
    }
}


=head2 C<init_instance>

=cut

sub init_instance {
    my $self = shift;

    # resource type is always slot!
    $self->{meta}->{'resource-type'} = 'slot';

    if ( ( !$self->{meta}->{name} ) && $self->{DB_KEY} ) {
        $self->{meta}->{name} = $self->{DB_KEY};
    }
    elsif ( $self->{meta}->{name} && ( !$self->{DB_KEY} ) ) {
        $self->{DB_KEY} = $self->{meta}->{name};
    }

    # set diskname if necessary
    unless ( $self->{meta}->{diskname} ) {
        $self->{meta}->{diskname} = LetsMT::Repository::Safesys::safe_filesys_unique_name(
            "/" . $self->{meta}->{name}
        );
    }

    # set partition if necessary
    unless ( $self->{meta}->{partition} ) {
        $self->{meta}->{partition} = $DEFAULT_PARTITION;
    }

    # is locked used at all?
    unless ( $self->{meta}->{locked} ) {
        $self->{meta}->{locked} = 0;
    }
}


=head2 Returning parameters

=head3 C<name>

=head3 C<diskname>

=head3 C<partition>

=head3 C<locked>

=head3 C<type>

=cut

# return parameters

sub name      { return $_[0]->{meta}->{name}; }
sub diskname  { return $_[0]->{meta}->{diskname}; }
sub partition { return $_[0]->{meta}->{partition}; }
sub locked    { return $_[0]->{meta}->{locked}; }

sub type {
    if ( !defined $_[0]->{meta}->{storage_type} ) {
        $_[0]->{meta}->{storage_type} = $ENV{VC_BACKEND};
    }
    return $_[0]->{meta}->{storage_type};
}


=head2 C<retrieve>

=cut

sub retrieve {
    my $self  = shift;
    my %query = @_;

    $query{'resource-type'} = 'slot';

    # use name to match internal _ID_
    if ( $query{name} ) {
        $query{'_ID_'} = $query{name};
    }
    delete $query{name};
    return $self->SUPER::retrieve(%query);
}


=head2 C<is_locked>

 is_locked ($name)

# UNCHECKED, PROBABLY OBSOLETE, REMOVE

=cut

sub is_locked {
    my ( $self, $name ) = @_;
    return $self->locked();
}


=head2 C<set_lock>

 set_lock ($status)

# UNCHECKED, PROBABLY OBSOLETE, REMOVE

=cut

sub set_lock {
    my ( $self, $status ) = @_;
    $self->locked($status);
    $self->save;
}


=head2 C<may_write>

=cut

sub may_write {
    return 1;
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
