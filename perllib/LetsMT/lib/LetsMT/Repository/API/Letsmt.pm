package LetsMT::Repository::API::Letsmt;

=head1 NAME

LetsMT::Repository::API::Letsmt - API class for the REST URI C<letsmt>

=head1 SYNOPSIS

 use LetsMT::Repository::API::Letsmt;

 my $letsmt = LetsMT::Repository::API::Letsmt;
 $letsmt->new($r);
 $letsmt->process;

=head1 DESCRIPTION

This class implements the functionality available through the REST URI
C<letsmt> - GET, PUT, POST and DELETE - and returns the result as a XML string.

=cut

use strict;
use parent 'LetsMT::Repository::API';

use open qw(:std :utf8);

use URI::Query;
use URI::Escape;

use Log::Log4perl qw(get_logger :levels);
use LetsMT::Repository::Err;
use Data::Dumper;


### CLASS METHOD ############################################################
# Usage      : LetsMT::Repository::API::Letsmt->new($r);
# Purpose    : Constructor, creates an instance of API::Letsmt class
# Returns    : Blessed hash_ref inheriting from LetsMT::Repository::API
# Parameters : hash_ref storing details from the mod_perl request
# Throws     : no exceptions
# Comments   : Overwrites constructor/factory method from parent

sub new {
    my ( $class, $ref_r ) = @_;
    #get_logger(__PACKAGE__)->debug( Dumper($ref_r) );

    bless $ref_r, $class;
}


=head1 METHODS

=head2 C<get>

Execute GET request by forwarding the call to storage API.

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::API::Letsmt->get();
# Purpose    : Execute GET request by forwarding the call to storage API
# Returns    : The result of the request
# Parameters : none
# Throws     : no exceptions
# Comments   : Overwrites get method from parent

sub get {
    my $self = shift;

    # Forward call to storage API
    my $result = _forward_to_storage( $self->{r} );

    return $result;
}


=head2 C<put>

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::API::Letsmt->put();
# Purpose    : Execute PUT request
# Returns    : The result of the request
# Parameters : none
# Throws     : no exceptions
# Comments   : Overwrites put method from parent

sub put {
    my $self = shift;

    # Forward call to storage API
    my $result = _forward_to_storage( $self->{r}, { action => 'import' } );

    return $result;
}


=head2 C<post>

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::API::Letsmt->post();
# Purpose    : Execute POST request
# Returns    : The result of the request
# Parameters : none
# Throws     : no exceptions
# Comments   : Overwrites post method from parent

sub post {
    my $self = shift;

    # Forward call to storage API
    my $result = _forward_to_storage( $self->{r} );

    return $result;
}


=head2 C<delete>

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::API::Letsmt->delete();
# Purpose    : Execute DELETE request by forwarding the call to storage API
# Returns    : The result of the request
# Parameters : none
# Throws     : no exceptions
# Comments   : Overwrites delete method from parent

sub delete {
    my $self = shift;

    # Forward call to storage API and add delete meta argument
    my $result = _forward_to_storage( $self->{r}, { action => 'delete_meta' } );

    return $result;
}


=head1 INTERNAL UTILITY METHOD

=head2 C<_forward_to_storage>

Forward function call to storage API by creating a new object.

=cut

### INTERNAL UTILITY METHOD ###################################################
# Usage      : LetsMT::Repository::API::Letsmt->_forward_to_storage($r, $args);
# Purpose    : Forwards function call to storage API by creating a new object
# Returns    : the result of process function call
# Parameters : a reference to the mod_perl r-object and optional URL arguments
# Throws     : no exceptions
# Comments   :

sub _forward_to_storage() {
    my $r    = shift;
    my $args = shift;

    my $r_ref = {};

    # Change 'letsmt' to 'storage' in the uri of mod_perl's r-object
    # This is used to determine what kind of API object to create

    # Split path_info and store parts in an array
    my @tmp_path_elements = grep {/\S/} split( /\/+/, $r->uri );

    my $q        = URI::Query->new( $r->args );
    my %tmp_args = $q->hash_arrayref();
    map {
        $tmp_args{ &LetsMT::Tools::unescape($_) }
            = &LetsMT::Tools::unescape( $tmp_args{$_}[0] )
        } keys %tmp_args
        ; #flatening out arrays with possibly multiple values by keeping only the first element
    %{ $$r_ref{args} } = %tmp_args;

    # Swap path element 'letsmt' with 'storage'
    splice( @tmp_path_elements, 1, 1, 'storage' );

    raise( 12, 'uid', 'warn' )
        unless defined $r_ref->{args}->{uid};

    # Add uid as branch element unless only api/slot parts present
    splice( @tmp_path_elements, 3, 0, $r_ref->{args}->{uid} )
        unless ( scalar @tmp_path_elements <= 2 );

    # Write changed path_info back to r-object
    $r->uri( '/' . join( '/', @tmp_path_elements ) );

    # Add additional URL arguments if any given to trigger activities
    # automatically provided by the letsmt-API, like import, delete meta data
    if ( defined $args && ref $args eq 'HASH' ) {
        map { $r_ref->{args}->{$_} = $args->{$_} } keys %$args;
    }

    get_logger(__PACKAGE__)
        ->debug( 'forwarding: ' . $r->uri . ', args: ' . $r->args );

# Create a new API object, this time of type 'storage' and call its process function
    my $api_object = LetsMT::Repository::API->new( $r, $r_ref );

    return $api_object->process();    # TODO: add eval
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