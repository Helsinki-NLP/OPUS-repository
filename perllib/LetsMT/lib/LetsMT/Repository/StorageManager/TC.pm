package LetsMT::Repository::StorageManager::TC;

=head1 NAME

LetsMT::Repository::StorageManager::TC - persistent object class for LetsMT's StorageManager

=cut

use strict;

use open qw(:std :utf8);

use Log::Log4perl qw(get_logger :levels);
use LetsMT::Repository::Err;

use LetsMT::Repository::MetaManager;

=head1 CONSTRUCTOR

Returns: a TC object.

=cut

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;
    $self->make_instance(@_);

    $self->{DB} = new LetsMT::Repository::MetaManager();
    return $self;
}


=head1 METHODS

=head2 C<make_instance>

Abstract method, overridden in children.

=cut

# make a new instance of the selected object
sub make_instance {
    my $self = shift;
    die "make instance is not implemented in base clase ...\n";
}


=head2 C<init_instance>

Abstract method, overridden in children.

=cut

# default: do nothing ...
sub init_instance { }


=head2 C<store>

=cut

sub store {
    my $self = shift;
    return $self->save(@_);
}


=head2 C<save>

=cut

sub save {
    my $self = shift;
    $self->{DB}->open() || raise( 7, "cannot open meta database", 'error' );
    $self->{DB}->post( $self->{DB_KEY}, $self->{meta} )
        || raise( 7, "cannot post slot data ($self->{DB_KEY})", 'error' );
    $self->{DB}->close();
    return 1;
}


=head2 C<delete>

=cut

sub delete {
    my $self = shift;
    if ( $self->{DB_KEY} ) {
        $self->{DB}->open() || raise(
            7, "cannot open meta database", 'error'
        );
        $self->{DB}->delete( $self->{DB_KEY} ) || raise(
            7, "cannot delete meta data ($self->{DB_KEY})", 'error'
        );
        $self->{DB}->close();
    }
    return 1;
}


=head2 C<retrieve>

=cut

# retrieve matching objects and return the first one from the list
# or the list of matching keys in array context

sub retrieve {
    my $self  = shift;
    my %query = @_;

    $self->{DB}->open_read() || raise(
        7, "cannot open meta database", 'error'
    );
    my $ids = $self->{DB}->search( \%query );
    $self->{DB}->close();

    # use a hash to make sure that we only store unique ids
    $self->{OBJECTS} = {};
    foreach ( @{$ids} ) { $self->{OBJECTS}->{$_} = 1; }

    return keys %{ $self->{OBJECTS} } if wantarray;
    return $self->restore_next();
}


=head2 C<find>

Alias of C<retrieve>.

=cut

sub find {
    my $self = shift;
    return $self->retrieve(@_);
}


=head2 C<restore_next>

Restore the next object.

=cut

sub restore_next {
    my $self = shift;

    ## no objects stored? --> return undef
    return 0 unless ( ref( $self->{OBJECTS} ) eq 'HASH' );
    return 0 if ( not keys %{ $self->{OBJECTS} } );

    $self->{DB}->open_read() || raise(
        7, "cannot open meta database", 'error'
    );

    # get next key and the corresponding meta data
    ( $self->{DB_KEY} ) = each %{ $self->{OBJECTS} };
    delete $self->{OBJECTS}->{ $self->{DB_KEY} };
    $self->{meta} = $self->{DB}->get( $self->{DB_KEY} );

    $self->{DB}->close();

    return undef if ( !keys %{ $self->{meta} } );

    ## initialize object
    $self->init_instance();
    return $self;
}


=head2 C<make_idquery>

Returns: just the query parameters.

=cut

sub make_idquery { return @_; }


=head2 C<may_write>

 may_write ($self, $user, $groups)

# Check whether this instance may be written to by the effective user.

## FIXME: this seems malplaced, is it even used? The subs in Branch is probably the right stuff.

# Returns: true or false

=cut

sub may_write {
    return 0;
}


=head2 C<may_read>

 may_read ($self, $user, $groups)

Returns: true or false

=cut

sub may_read {
    my ( $self, $user, $groups ) = @_;

    return 1 if ( $self->{meta}->{owner}   eq $user );
    return 1 if ( $self->{meta}->{creator} eq $user );
    return 1 if ( grep ( $self->{meta}->{gid} eq $_, @{$groups} ) );
    return 0;
}


=head2 C<drop_table>

nothing to do here ....

=cut

sub drop_table { }


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