package LetsMT::Repository::API::MetaData;

=head1 NAME

LetsMT::Repository::API::MetaData - API class for the REST URI C<metadata>

=head1 SYNOPSIS

 use LetsMT::Repository::API::MetaData;

 my $metadata = LetsMT::Repository::API::MetaData;
 $metadata->new($r);
 $metadata->process;

=head1 DESCRIPTION

This class implements the functionality available through the REST URI
C<letsmt> - GET, PUT, POST and DELETE - and returns the result as a XML string.

=cut

use strict;
use parent 'LetsMT::Repository::API';

use open qw(:std :utf8);

use LetsMT::Repository::MetaManager;
use LetsMT::Repository::GroupManager;

use Data::Dumper;
use Log::Log4perl qw(get_logger :levels);
use LetsMT::Repository::Err;


### CLASS METHOD ############################################################
# Usage      : LetsMT::Repository::API::MetaData->new($r);
# Purpose    : Constructor, creates an instance of API::MetaData class
# Returns    : Blessed hash_ref inherriting from LetsMT::Repository::API
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

Search for meta data by resource path (id) or key/values. (?)

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::API::MetaData->get();
# Purpose    : Searching for meta data by resource path (id) or key/values
# Returns    : The result of the request
# Parameters : none
# Throws     : no exceptions
# Comments   : Overwrites get method from parent

sub get {
    my $self = shift;

    my $message = undef;

    # uid is required
    raise( 12, 'parameter uid', 'warn' ) unless (length $self->{args}->{uid});

    my $result = undef;
    my $path   = join( "/", @{ $self->{path_elements} });

    # If a path is given, and type is not recursive:
    # the entry for that resource is returned if any,
    # otherwise a search by key/values is done

    if ( length $self->{path_elements}[0] ) {

        ## recursive search within a given path
        if ( $self->{args}->{type} && $self->{args}->{type} eq "recursive" ) {
            ## remove 'type' to exclude it from the search
            delete $self->{args}->{type};

            # use the internal _ID_ field as search condition
            $self->{args}->{STARTS_WITH__ID_} = $path . '/';
            $result = $self->search( \$message );
        }

        # no need to search: simply fetching the data record is enough
        else {
            # specific revision? --> add revision number (history records)
            if (exists $self->{args}->{rev}) {
                $self->{path_elements}->[-1] .= '@'.$self->{args}->{rev};
            }
            my $metaDB = new LetsMT::Repository::MetaManager();

            # Get the gid and owner of the resource and the groups of the user 
            # to check if they match 
            $metaDB->open_read();
            my $resource_group = $metaDB->get_gid( $path );
            my $resource_owner = $metaDB->get_owner( $path );
            $metaDB->close();
            my $user_groups = LetsMT::Repository::GroupManager::get_groups_for_user(
                $self->{args}->{uid}
            );

            # resource gid on slot level is always empty and can be ignored
            if ( (grep {$_ eq $resource_group} @{$user_groups})
                || ! $resource_group
                || $resource_owner eq $self->{args}->{uid}
            ) {
                $metaDB->open_read();
                $result = $metaDB->get_xml(
                    \$message,
                    join( "/", @{ $self->{path_elements} } ),
                    $self->{args}
                );
                $metaDB->close();
            } else {
                $message = "User '$self->{args}->{uid}' has no access to this resource";
            }
        }
    }
    else {
        $result = $self->search( \$message );
    }

    # Success if we got here, prepare Result object and return it
    my $result_obj = LetsMT::Repository::Result->new(
        type      => 'ok',
        code      => 0,
        operation => 'GET',
        location  => $self->{path_info},
        lists     => \$result,
        message   => $message,
    );
    return $result_obj->get_xml_result();
}


=head2 C<search>

Search for meta data by resource path (id) and key/values.

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::API::MetaData->search( $type, $message );
# Purpose    : Searching for meta data by resource path (id) and key/values
# Returns    : The result of the request
# Parameters : none
# Throws     : no exceptions
# Comments   :

sub search {
    my $self    = shift;
    my $message = shift;

    my $uid = $self->{args}->{uid};

    # Check if user actually exists
    my $groups = LetsMT::Repository::GroupManager::get_groups_for_user( $uid );
    unless ( scalar (@{$groups}) ) { raise(15, $uid); }

    # effectiv user will be used in query but will not be used as query term 
    delete $self->{args}->{uid};

    # user can only find resources for which they have read permissions
    # --> add group condition to query to take care of this
    _add_group_condition( $self->{args}, $uid );

    # exclude all entries that are marked as 'history' records
    ## TODO: '_METADATATYPE_' is now a reserved word and
    ##        should not be used otherwise! --> add to documentation!!!
    $self->{args}->{'NOT__METADATATYPE_'} = 'history';

    my $metaDB = new LetsMT::Repository::MetaManager();
    $metaDB->open_read();

    my $result = undef;

    # if action was "list_all",
    # all matching entries with their key/value pairs gets listed
    if ( exists $self->{args}->{action}
        && $self->{args}->{action} eq "list_all"
    ) {
        # remove action-key so it is not searched later
        delete $self->{args}->{action};
        $result = $metaDB->search_xml( 1, $message, $self->{args} );
    }

    # if action was "count": return only the number of matching entries
    elsif ( exists $self->{args}->{action}
        && $self->{args}->{action} eq "count"
    ) {
        # remove action-key so it is not searched later
        delete $self->{args}->{action};
        $result = $metaDB->search_xml( 3, $message, $self->{args} );
    }

    # default: "list_ids", lists only the IDs of entries that had a match
    else {
        $result = $metaDB->search_xml( 2, $message, $self->{args} );
    }

    $metaDB->close();
    return $result;
}


=head2 C<put>

Create/extend metadata entry.

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::API::MetaData->put();
# Purpose    : Create/Extend meta data entry
# Returns    : The result of the request
# Parameters : none
# Throws     : no exceptions
# Comments   : Overwrites put method from parent

sub put {
    my $self = shift;

    # uid is required!
    # store uid in 'owner'
    # TODO: need to make sure that uid may write this record!
    $self->{args}->{uid} || raise( 12, 'parameter uid', 'warn' );
    $self->{args}->{owner} = $self->{args}->{uid};
    delete $self->{args}->{uid};
    my $path = join( "/", @{ $self->{path_elements} } );

    my $metaDB = new LetsMT::Repository::MetaManager();
    $metaDB->open();

    # only the owner may write metadata!
    if ( $self->{args}->{owner} eq $metaDB->get_owner($path) ) {
        $metaDB->put( $path, $self->{args} );
        $metaDB->close();
    }
    else {
        $metaDB->close();
        raise( 14, 'uid', 'warn' );
    }

    # Success if we got here, prepare Result object and return it
    my $result_obj = LetsMT::Repository::Result->new(
        type      => 'ok',
        code      => 0,
        operation => 'PUT',
        location  => $self->{path_info},
        message   => 'Created/Extended meta data entry',
    );
    return $result_obj->get_xml_result();
}


=head2 C<post>

Create/overwrite metadata entry.

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::API::MetaData->post();
# Purpose    : Create/Overwrite meta data entry
# Returns    : The result of the request
# Parameters : none
# Throws     : no exceptions
# Comments   : Overwrites post method from parent

sub post {
    my $self = shift;

    # uid is required!
    # store uid in 'owner'
    $self->{args}->{uid} || raise( 12, 'parameter uid', 'warn' );
    $self->{args}->{owner} = $self->{args}->{uid};
    delete $self->{args}->{uid};
    my $path = join( "/", @{ $self->{path_elements} } );

    my $metaDB = new LetsMT::Repository::MetaManager();
    $metaDB->open();

    # only the owner may write metadata!
    if ( $self->{args}->{owner} eq $metaDB->get_owner($path) ) {
        $metaDB->post( $path, $self->{args} );
        $metaDB->close();
    }
    else {
        $metaDB->close();
        raise( 14, 'uid', 'warn' );
    }

    # Success if we got here, prepare Result object and return it
    my $result_obj = LetsMT::Repository::Result->new(
        type      => 'ok',
        code      => 0,
        operation => 'POST',
        location  => $self->{path_info},
        message   => 'Created/Overwrote meta data entry',
    );
    return $result_obj->get_xml_result();
}


=head2 C<delete>

Delete metadata entry.

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::API::MetaData->delete();
# Purpose    : Execute DELETE request by forwarding the call to storage API
# Returns    : The result of the request
# Parameters : none
# Throws     : no exceptions
# Comments   : Overwrites delete method from parent

#TODO: returns OK if trying to delete a non-existing value from a key

sub delete {
    my $self = shift;
    
    $self->{args}->{uid} || raise( 12, 'parameter uid', 'warn' );

    my $metaDB = new LetsMT::Repository::MetaManager();
    $metaDB->open();

    # keys (and values) to be deleted
    # (remove uid!)
    my %keys = %{ $self->{args} };
    delete $keys{uid};

    # only the owner may delete metadata!
    my $path = join( "/", @{ $self->{path_elements} } );
    my $result = undef;
    if ( $self->{args}->{uid} eq $metaDB->get_owner($path) ) {
        $result = $metaDB->delete( $path, %keys );
        $metaDB->close();
    }
    else {
        $metaDB->close();
        raise( 14, 'uid', 'warn' );
    }

    # Success if we got here, prepare Result object and return it
    my $result_obj = LetsMT::Repository::Result->new(
        type      => 'ok',
        code      => 0,
        operation => 'DELETE',
        location  => $self->{path_info},
        message   => 'Deleted meta data entry',
    );
    return $result_obj->get_xml_result();
}


=head1 INTERNAL UTILITY METHODS

=head2 C<_add_group_condition>

Add condition for user groups to current query in order to handle permissions.

=cut

### INTERNAL UTILITY METHOD ###################################################
# Usage      : LetsMT::Repository::API::MetaData-> _add_group_condition($search, $uid);
# Purpose    : Adds query condition for user groups to handle permissions
# Returns    : true or false
# Parameters : 
# Throws     : no exceptions
# Comments   :

sub _add_group_condition {
    my ( $search, $uid ) = @_;
    if ($uid) {
        my $groups
            = &LetsMT::Repository::GroupManager::get_groups_for_user($uid);

        # if there is gid in the search query:
        # delete all groups from the query for which uid is not a member of
        if ( exists $search->{gid} ) {
            my @query_groups = split( ',', $search->{gid} );
            my @accepted = ();
            foreach my $g (@query_groups) {
                if ( grep ( $_ eq $g, @{$groups} ) ) {
                    push( @accepted, $g );
                }
            }
            @{$groups} = @accepted;
        }
        $search->{ONE_OF_gid} = join( ',', @{$groups} );
    }
}


=head2 C<_forward_to_storage>

Forward function call to storage API by creating a new object.

=cut

### INTERNAL UTILITY METHOD ###################################################
# Usage      : LetsMT::Repository::API::MetaData->_forward_to_storage($r, $args);
# Purpose    : Forwards function call to storage API by creating a new object
# Returns    : the result of process function call
# Parameters : a reference to the mod_perl r-object and optional URL arguments
# Throws     : no exceptions
# Comments   :

sub _forward_to_storage() {
    my $r    = shift;
    my $args = shift;

    my $r_ref = {};

    # Change 'letsmt' to 'storage' in path_info of mod_perl's r-object
    # This is used to determine what kind of API object to create

    # Split path_info and store parts in an array
    my @tmp_path_elements = grep {/\S/} split( /\/+/, $r->path_info );

    # Get URL arguments and add them to r_ref
    my @tmp_args = map { split( "=", $_ ) } split( /&|;/, $r->args );
    while ( my ( $k, $v ) = splice @tmp_args, 0, 2 ) {
        $r_ref->{'args'}->{$k} = $v;
    }

    # Swap path element 'letsmt' with 'storage'
    splice( @tmp_path_elements, 0, 1, 'storage' );

    # Add uid as branch element unless only api/slot parts present
    splice( @tmp_path_elements, 2, 0, $r_ref->{args}->{uid} )
        unless ( scalar @tmp_path_elements <= 1 );

    # Write changed path_info back to r-object
    $r->path_info( '/' . join( '/', @tmp_path_elements ) );

    # Add additional URL arguments if any given to trigger activities
    # automatically provided by the letsmt-API, like import, delete meta data
    if ($args) {
        $r->args( join( '&', $r->args(), $args ) );
    }

    # Create a new API object, this time of type 'storage',
    # and call its process function
    my $api_object = LetsMT::Repository::API->new($r);

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
