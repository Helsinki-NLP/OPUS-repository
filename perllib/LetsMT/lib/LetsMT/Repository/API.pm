package LetsMT::Repository::API;

=head1 NAME

LetsMT::Repository::API - Interface and factory class for the API modules

=head1 SYNOPSIS

 # e.g. with child class Letsmt:
 use LetsMT::Repository::API::Letsmt;

 my $letsmt = LetsMT::Repository::API::Letsmt;
 $letsmt->new($r);
 $letsmt->process;

=head1 DESCRIPTION

This class provides the interface for the API classes,
and a factory method through its constructor.

=cut

use strict;
use Switch; ## Note: obsolescent - replace by v5.10 'given' statement?

use open qw(:std :utf8);

use URI::Query;
use URI::Escape;

use LetsMT::Repository::GroupManager;
use LetsMT::Tools;

use LetsMT::Repository::API::Access;
use LetsMT::Repository::API::Admin;
use LetsMT::Repository::API::Group;
use LetsMT::Repository::API::Job;
use LetsMT::Repository::API::Letsmt;
use LetsMT::Repository::API::MetaData;
use LetsMT::Repository::API::Storage;

use Data::Dumper;
$Data::Dumper::Useperl = 1;
use LetsMT::Repository::Err;
use Log::Log4perl qw(get_logger :levels);


=head1 CONSTRUCTOR / FACTORY METHOD

 $api = new LetsMT::Repository::API( $r )

Create the actual API classes.

Parameter C<$r> is a hashref containing relevant details of the mod_perl request object.

Returns a class instance that inherits methods from this class, or undef.
Has to be overwritten with normal constructor in child class.

=cut

### CLASS METHOD ############################################################
# Usage      : LetsMT::Repository::API->new($r);
# Purpose    : Constructor and factory method, creates the actual API classes
# Returns    : Class instance that inherrits methods from this class or error string
# Parameters : $r request object from mod_perl
# Throws     : no exceptions
# Comments   : Has to be overwritten with normal constructor in child class
# See Also   : N/A

sub new {
    my ( $class, $r, $forwarded_r_ref ) = @_;
    my $logger = get_logger(__PACKAGE__);

    # Hash_ref to store all needed information of the request
    # utf8_to_perl makes sure that Perl recognizes path elements as utf8!!!
    my $r_ref = {
        http_method => $r->method,
        path_info   => &utf8_to_perl( $r->path_info ),
        uri         => &utf8_to_perl( $r->uri ),
        r => $r, # Store reference to r-object to pass it on to the letsmt API
    };

    # If forwarded from Letsmt API to Storage
    if ( defined $forwarded_r_ref && ref $forwarded_r_ref eq 'HASH' ) {
        map { $r_ref->{$_} = $forwarded_r_ref->{$_} } keys %$forwarded_r_ref;
    }
    else {
        # parse URI query parameters
        my $q        = URI::Query->new( $r->args );
        my %tmp_args = $q->hash_arrayref();
        ## flattening out arrays with possibly multiple values
        ## by keeping only the first element

        map {
            $$r_ref{args}{ &LetsMT::Tools::unescape($_) }
                = &LetsMT::Tools::unescape( $tmp_args{$_}[0] )
            }
            keys %tmp_args;
    }

    # Check if uid agument is set if actually is an existing user
    unless ( $r_ref->{args}->{uid} ) {
        $logger->error( "Missing uid!" );
        return { message => 'Missing user ID (uid)', code => 12 };
    };

    # Split uri string and shift off ws- and api-path element
    my @tmp_path_elements = grep {/\S/} split( /\/+/, $r_ref->{uri} );

    my $ws  = shift(@tmp_path_elements);
    my $api = shift(@tmp_path_elements);

    # Store path elements in r_ref as array ref
    $r_ref->{'path_elements'} = \@tmp_path_elements;

    # For letsmt-API add uid as branch name
    if ( $api =~ /^letsmt$/i ) {
        splice( @{ $r_ref->{path_elements} }, 1, 0, $r_ref->{args}->{uid} );
    }

    # handle revision numbers
    &_handle_resource_revision($r_ref);

    # Log the API call
    if ( $logger->is_debug() ) {
        $logger->debug(
            $r_ref->{http_method} .
            ' '        . $api,
            ', PATH: ' . Dumper($r_ref->{path_elements}),
            ', ARGS: ' . Dumper($r_ref->{args}),
        );
    }

    my $api_class    = undef;
    my @allowed_APIs = qw(access admin group job letsmt metadata storage);

    # Find API class keyword and assign class
    $api_class = 'LetsMT::Repository::API::Access'   if ($api =~ /^access$/i);
    $api_class = 'LetsMT::Repository::API::Admin'    if ($api =~ /^admin$/i);
    $api_class = 'LetsMT::Repository::API::Group'    if ($api =~ /^group$/i);
    $api_class = 'LetsMT::Repository::API::Job'      if ($api =~ /^job$/i);
    $api_class = 'LetsMT::Repository::API::Letsmt'   if ($api =~ /^letsmt$/i);
    $api_class = 'LetsMT::Repository::API::MetaData' if ($api =~ /^metadata$/i);
    $api_class = 'LetsMT::Repository::API::Storage'  if ($api =~ /^storage$/i);

    # If valid API class keyword found, create and return new instance
    if ($api_class) {
        return $api_class->new($r_ref);
    }
    else {
        $logger->error(
            "Invalid API name '$api' called, must be one of: "
            . join(', ', @allowed_APIs)
        );
        return { message => 'Invalid API name', code => 17 };
    }
}


=head1 INSTANCE METHOD

=head2 C<process>

 $result = &$api->process

Call requested method of child class and return the result.

Returns the result of the request as XML string, or undef.

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::API->process();
# Purpose    : Calls requested method of child class and returns result
# Returns    : The result of the request as XML string or undef
# Parameters : none
# Throws     : no exceptions
# Comments   : none
# See Also   : N/A

sub process {
    my $self = shift;

    my $http_method = $self->{http_method};
    my $result      = undef;

    switch ($http_method) {
        case 'DELETE' { $result = $self->delete(); }
        case 'GET'    { $result = $self->get(); }
        case 'HEAD'   { $result = $self->get(); }  # HEAD is GET as far as letsmt is concerned
        case 'POST'   { $result = $self->post(); }
        case 'PUT'    { $result = $self->put(); }
        else {
            get_logger(__PACKAGE__)->error( 'HTTP method ' . $http_method . ' not supported' );
            raise( 17, 'method \'' . $http_method . '\' called', 'warn' );
        }
    }
    return $result;
}


=head1 INTERFACE METHODS

=head2 C<get> | C<put> | C<post> | C<delete>

! These methods provide only an interface and have to be implemented by the child class !

=cut

sub get {
    my $self = shift;
    # Return error message if method is not implemented in child class
    my $result_obj = LetsMT::Repository::Result->new(
        type      => 'error',
        code      => 13,
        operation => 'GET',
        location  => $self->{path_info},
        message   => 'GET not implemented for this API',
    );
    return $result_obj->get_xml_result();
}


sub put {
    my $self = shift;
    # Return error message if method is not implemented in child class
    my $result_obj = LetsMT::Repository::Result->new(
        type      => 'error',
        code      => 13,
        operation => 'PUT',
        location  => $self->{path_info},
        message   => 'PUT not implemented for this API',
    );
    return $result_obj->get_xml_result();
}


sub post {
    my $self = shift;
    # Return error message if method is not implemented in child class
    my $result_obj = LetsMT::Repository::Result->new(
        type      => 'error',
        code      => 13,
        operation => 'POST',
        location  => $self->{path_info},
        message   => 'POST not implemented for this API',
    );
    return $result_obj->get_xml_result();
}


sub delete {
    my $self = shift;
    # Return error message if method is not implemented in child class
    my $result_obj = LetsMT::Repository::Result->new(
        type      => 'error',
        code      => 13,
        operation => 'DELETE',
        location  => $self->{path_info},
        message   => 'DELETE not implemented for this API',
    );
    return $result_obj->get_xml_result();
}


## helper function that returns the requested revision number
## - can be given as argument 'rev' OR
## - can be part of the resource name (suffix '@xx' with xx=revision number)
##   (which will be removed from the path)

sub _handle_resource_revision{
    my $r_ref = shift;

    return undef unless (ref($r_ref) eq 'HASH');
    return undef unless (ref($r_ref->{args}) eq 'HASH');

    return $r_ref->{args}->{rev} if (defined $r_ref->{args}->{rev});

    if (exists $r_ref->{path_elements}){
        if (ref($r_ref->{path_elements}) eq 'ARRAY'){
            if (@{$r_ref->{path_elements}}){
                if ($r_ref->{path_elements}->[-1]=~s/\@([0-9]+)$//){
                    $r_ref->{args}->{rev} = $1;
                    return $r_ref->{args}->{rev};
                }
            }
        }
    }
    return undef;
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