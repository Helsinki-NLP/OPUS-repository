package LetsMT::Repository::StorageManager::TC::Branch;

=head1 NAME

LetsMT::Repository::StorageManager::TC::Branch

=cut

use strict;
use parent 'LetsMT::Repository::StorageManager::TC';

use open qw(:std :utf8);

use LetsMT::Repository::MetaManager;
use LetsMT::Repository::StorageManager::TC::Slot;

use Log::Log4perl qw(get_logger :levels);
use Data::Dumper;
use LetsMT::Repository::Safesys;
use LetsMT::Repository::Err;

# TODO: do we like to support fine-grained permission settings?
# (now: just apply default settings rwr---)
# TODO: why do we need $repos?


=head1 METHODS

=head2 C<make_instance>

=cut

sub make_instance {
    my $self = shift;
    my ($repos,      $name,      $slot,      $owner,
        $grp,        $userread,  $userwrite, $groupread,
        $groupwrite, $otherread, $otherwrite
    ) = @_;

    if ($repos) {

        $self->{DB_KEY} = $slot . '/' . $name;

        my $metaDB = new LetsMT::Repository::MetaManager();
        $metaDB->open() || raise( 7, "cannot open meta database", 'error' );
        my $data = $metaDB->get( $self->{DB_KEY} );

        ## branch exists already! --> fail!
        raise( 4, "slot $slot/$name", 'error' ) if ( keys %{$data} );

        # set other values
        $self->{meta}->{name}  = $name;
        $self->{meta}->{gid}   = $grp;
        $self->{meta}->{owner} = $owner;

        my $time = LetsMT::Repository::Safesys::time();
        $self->{meta}->{create} = $time;
        $self->{meta}->{acces}  = $time;
        $self->{meta}->{modif}  = $time;

        # initialize (not really necessary)
        $self->init_instance();

        # store meta-data
        $metaDB->post( $self->{DB_KEY}, $self->{meta} )
            || raise( 7, "cannot post branch data ($name)", 'error' );

        # add branch name to list of branches in slot
        $metaDB->put( $slot, { branches => $self->{meta}->{name} } )
            || raise( 7, "cannot put slot data ($name)", 'error' );

        $metaDB->close();

        # get info about slot (handy for restore-next function)
        $self->{slot} = new LetsMT::Repository::StorageManager::TC::Slot();
        $self->{slot}->retrieve( name => $slot );

        $self->{branches} = split( /,/, $self->{slot}->{branches} );
    }
}


=head2 C<init_instance>

=cut

sub init_instance {
    my $self = shift;

    # resource type is always branch!
    $self->{meta}->{'resource-type'} = 'branch';

    # set slot and name if necessary
    unless ( $self->{meta}->{name} && $self->{meta}->{slot} ) {
        if ( $self->{DB_KEY} ) {
            my ( $slot, $name ) = split( /\//, $self->{DB_KEY} );
            $self->{meta}->{name} = $name unless ( $self->{meta}->{name} );
            $self->{meta}->{slot} = $slot unless ( $self->{meta}->{slot} );
        }
    }
    $self->{meta}->{gid} = 'public' unless ( $self->{meta}->{gid} );
    unless ( $self->{meta}->{owner} ) {
        $self->{meta}->{owner} = $self->{meta}->{name};
    }

    # DB_KEY is necessary for store & delete!!
    $self->{DB_KEY} = $self->{meta}->{slot} . '/' . $self->{meta}->{name};
}


=head2 Returning parameters

=head3 C<name>

=head3 C<owner>

=head3 C<grp>

=head3 C<create>

=head3 C<acces>

=head3 C<modif>

=head3 C<slot>

=cut

# return parameters

sub name   { return $_[0]->{meta}->{name}; }
sub owner  { return $_[0]->{meta}->{owner}; }
sub grp    { return $_[0]->{meta}->{gid}; }
sub create { return $_[0]->{meta}->{create}; }
sub acces  { return $_[0]->{meta}->{acces}; }
sub modif  { return $_[0]->{meta}->{modif}; }

sub slot   { return $_[0]->{slot}->name(); }


=head2 C<retrieve>

=cut

sub retrieve {
    my $self   = shift;
    my %params = @_;

    my %query = ( 'resource-type' => 'branch' );

    #get_logger(__PACKAGE__)->debug( 'params: ' . Dumper(%params) );

    # modify query in case slot and/or name are given
    # (to match _ID_)
    if ( $params{slot} ) {
        if ( $params{name} ) {
            $query{'_ID_'} = $params{slot} . '/' . $params{name};
        }
        else {
            $query{'STARTS_WITH__ID_'} = $params{slot} . '/';
        }
    }
    elsif ( $params{name} ) {
        $query{'ENDS_WITH__ID_'} = '/' . $query{params};
    }

    # easy: superuser view --> just show all
    if ( $params{superuser_view} ) {
        return $self->SUPER::retrieve(%query);
    }

    # otherwise: need to find the ones owned by the given user
    # or readable by the user through matching group settings

    my ( @owned, @readable );
    if ( $params{user} ) {
        $query{owner} = $params{user};
        @owned = $self->SUPER::retrieve(%query);
        #get_logger(__PACKAGE__)->debug( 'owned: ' . Dumper(@owned) );
    }

    if ( ref( $params{groups} ) eq 'ARRAY' ) {
        delete $query{owner};
        $query{ONE_OF_gid} = join( ',', @{ $params{groups} } );
        @readable = $self->SUPER::retrieve(%query);
        #get_logger(__PACKAGE__)->debug( 'readable: ' . Dumper(@readable) );
    }

    # put them all together
    $self->{OBJECTS} = {};
    foreach (@owned)    { $self->{OBJECTS}->{$_} = 1; }
    foreach (@readable) { $self->{OBJECTS}->{$_} = 1; }

    return keys %{ $self->{OBJECTS} } if wantarray;
    return $self->restore_next();
}


=head2 C<may_read>

 may_read ($self, $user, $groups)

Checks whether this Branch may be read to by the effective user.

Returns: true or false

=cut

sub may_read {
    my ( $self, $user, $groups ) = @_;

    return 1 if ( $self->{meta}->{owner} eq $user );
    return 1 if ( grep ( $self->{meta}->{gid} eq $_, @{$groups} ) );
    return 0;
}


=head2 C<may_write>

=cut

sub may_write {
    my ( $self, $user, $groups ) = @_;

    #TODO: $groups is passed but not used, why?
    return 1 if ( $self->{meta}->{owner} eq $user );
    return 0;
}


=head2 C<pp_perms>

 $string = $manager->pp_perms

Pretty-print the permissions of the data records
(presently in fact always 'rwr---').

Returns: pretty-printed string.

=cut

sub pp_perms { return 'rwr---'; }


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