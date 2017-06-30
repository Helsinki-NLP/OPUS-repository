package LetsMT::Repository::API::Access;

=head1 NAME

LetsMT::Repository::API::Group - API class for the REST URI C<group>

=head1 SYNOPSIS

 use LetsMT::Repository::API::Access;

 my $access = LetsMT::Repository::API::Access;
 $access->new($r);
 $access->process;

=head1 DESCRIPTION

This class implements the functionality available through the REST URI
C<access> - GET and PUT - and returns the result as a XML string.
Supports showing which group a slot is in and setting a new group for a slot. 

=cut

use strict;
use parent 'LetsMT::Repository::API';

use open qw(:std :utf8);

use Data::Dumper;
use Log::Log4perl qw(get_logger :levels);

use LetsMT::Repository::Err;
use LetsMT::Repository::Result;
use LetsMT::Repository::MetaManager;
use LetsMT::Repository::GroupManager;


### CLASS METHOD ############################################################
# Usage      : LetsMT::Repository::API::Access->new($r);
# Purpose    : Constructor, creates an instance of API::Access class
# Returns    : Blessed hash_ref inherriting from LetsMT::Repository::API
# Parameters : hash_ref storing details from the mod_perl request
# Throws     : no exceptions
# Comments   : Overwrites constructor/factory method from parent

sub new {
    my ( $class, $ref_r ) = @_;

    bless $ref_r, $class;
}


=head1 METHODS

=head2 C<get>

Get the group the given branch/slot is in.

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::API::Group->get();
# Purpose    : Get the group setting of a branch
# Returns    : The result of the request as XML string
# Parameters : none
# Throws     : no exceptions
# Comments   : Overwrites get method from parent

sub get {
    my $self = shift;

    my $result = undef;

    # Search for the group name and return results
    &LetsMT::Repository::StorageManager::get_access(
        \$result,
        $self->{path_elements},
        $self->{args}->{uid},
    );

    # Success if we got here, prepare Result object and return it
    my $result_obj = LetsMT::Repository::Result->new(
        operation => 'GET',
        status    => 200,
        location  => $self->{path_info},
        lists     => \$result,
    );

    return $result_obj->get_xml_result();
}


=head2 C<put>

Set a new group for the given branch/slot.

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::API::Access->put();
# Purpose    : Change the group setting of a branch
# Returns    : The result of the request as XML string
# Parameters : none
# Throws     : no exceptions
# Comments   : Overwrites put method from parent

sub put {
    my $self = shift;

    ## fail if the group does not exist (and is not public or uid)
    if (   ( $self->{args}->{gid} ne 'public' )
        && ( $self->{args}->{gid} ne $self->{args}->{uid} ) )
    {
        if (!LetsMT::Repository::GroupManager::group_exists(
                $self->{args}->{gid}
            )
            )
        {
            raise( 3, $self->{args}->{gid}, 'error' );
        }
    }

    # Sets the group of the given slot to gid
    &LetsMT::Repository::StorageManager::put_access(
        $self->{path_elements},
        $self->{args}->{uid},
        $self->{args}->{gid},
    );

    # need to set gid's for all metadata in the entire branch!
    my $metaDB = new LetsMT::Repository::MetaManager();
    $metaDB->open();
    my $branch = join( "/", $self->{path_elements}->[0],
        $self->{path_elements}->[1] );

    # need to set gid for the branch first
    # and then for all metadata records below ....
    $metaDB->post( $branch, { gid => $self->{args}->{gid} } );
    $metaDB->post_recursive( $branch, { gid => $self->{args}->{gid} } );
    $metaDB->close();

    # Success if we got here, prepare Result object and return it
    my $result_obj = LetsMT::Repository::Result->new(
        operation => 'PUT',
        status    => 201,
        location  => $self->{path_info},
        message   => 'Set group to \'' . $self->{args}->{gid} . '\'',
    );

    return $result_obj->get_xml_result();
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