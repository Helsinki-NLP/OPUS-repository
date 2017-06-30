package LetsMT::Repository::API::Group;

=head1 NAME

LetsMT::Repository::API::Group - API class for the REST URI C<group>

=head1 SYNOPSIS

 use LetsMT::Repository::API::Group;

 my $group = LetsMT::Repository::API::Group;
 $group->new($r);
 $group->process;

=head1 DESCRIPTION

This class implements the functionality available through the REST URI
C<group> - GET, PUT, POST and DELETE - and returns the result as a XML string.
Supports creation, listing and deletion of groups and users.

=cut

use strict;
use parent 'LetsMT::Repository::API';

use open qw(:std :utf8);

use Data::Dumper;
use Log::Log4perl qw(get_logger :levels);

use LetsMT::Repository::Result;


### CLASS METHOD ############################################################
# Usage      : LetsMT::Repository::API::Group->new($r);
# Purpose    : Constructor, creates an instance of API::Group class
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

List all the users in a group.
If called without a group name, list all groups and their users.

If additional arguments are given and the group name is equal to the uid:
List information about the given user instead of listing group members.

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::API::Group->get();
# Purpose    : Lists a group and its users or all groups if no group name given
# Returns    : The result of the request as XML string
# Parameters : none
# Throws     : no exceptions
# Comments   : Overwrites get method from parent


## TODO: need to implement get user info somehow
##       action = showinfo???

sub get {
    my $self = shift;

    my $group_name = $self->{path_elements}[0];
    my $uid        = $self->{args}->{uid};

    my $result     = undef;

    # if there are other arguments besides uid:
    # show user info instead of group listing
    if ((scalar keys %{$self->{args}} > 1) && ($group_name eq $uid)){
        my $user_info = 
            &LetsMT::Repository::GroupManager::get_user_info( $group_name );
        my %entry = ( id => $uid, kind => 'user info' );
        foreach my $data_key ( keys %$user_info ) {
            $entry{$data_key} = [ $user_info->{$data_key} ];
        }
        $result = { 'path'  => 'group/'.$uid, 'entry' => [ \%entry ] };
    }

    # Search for the group name and return results
    else{
        &LetsMT::Repository::GroupManager::read_group( \$result, 
                                                       $group_name, );
    }

    # Success if we got here, prepare Result object and return it
    my $result_obj = LetsMT::Repository::Result->new(
        type      => 'ok',
        code      => 0,
        operation => 'GET',
        location  => $self->{path_info},
        lists     => \$result,
    );

    return $result_obj->get_xml_result();
}


=head2 C<put>

Add a user to a group that already exists.

If additional arguments are given and the group name is equal to the uid:
Add user information.

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::API::Group->put();
# Purpose    : Adds a user to an existing group
# Returns    : The result of the request as XML string
# Parameters : none
# Throws     : no exceptions
# Comments   : Overwrites put method from parent

sub put {
    my $self = shift;

    my $group_name = $self->{path_elements}[0];
    my $user_name  = $self->{path_elements}[1];
    my $uid        = $self->{args}->{uid};
    my $message    = '';

    # Set user info if more than one argument is given and gid=uid
    if ((scalar keys %{$self->{args}} > 1) && ($group_name eq $uid)){
        my %data = %{$self->{args}};
        delete $data{uid};
        &LetsMT::Repository::GroupManager::add_user_info( $uid, %data );
        $message = "Added user info for user '$uid'";

    }

    # Add user to group and return results
    else{
        &LetsMT::Repository::GroupManager::add_user_to_group( $group_name,
            $user_name, $uid, );
        $message = "Added user '$user_name' to group '$group_name'";
    }

    # Success if we got here, prepare Result object and return it
    my $result_obj = LetsMT::Repository::Result->new(
        type      => 'ok',
        code      => 0,
        operation => 'PUT',
        location  => $self->{path_info},
        message   => $message
    );

    return $result_obj->get_xml_result();
}


=head2 C<post>

Add a user to a group and creates the group if does not exist yet.

If additional arguments are given and the group name is equal to the uid:
Add user information.

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::API::Group->post();
# Purpose    : Creates a new group with uid as a user
# Returns    : The result of the request as XML string
# Parameters : none
# Throws     : no exceptions
# Comments   : Overwrites post method from parent

sub post {
    my $self = shift;

    my $group_name = $self->{path_elements}[0];
    my $uid        = $self->{args}->{uid};
    my $message    = '';

    # Add user info if more than one argument is given and gid=uid
    if ((scalar keys %{$self->{args}} > 1) && ($group_name eq $uid)){
        my %data = %{$self->{args}};
        delete $data{uid};
        &LetsMT::Repository::GroupManager::set_user_info( $uid, %data );
        $message = "Set user info for user '$uid'";
    }

    # Add user to group and return results
    else{
        &LetsMT::Repository::GroupManager::create_group( $group_name, $uid, );
        $message = "Created group '$group_name' with user '$uid'";
    }


    # Success if we got here, prepare Result object and return it
    my $result_obj = LetsMT::Repository::Result->new(
        type      => 'ok',
        code      => 0,
        operation => 'POST',
        location  => $self->{path_info},
        message   => $message
    );

    return $result_obj->get_xml_result();
}


=head2 C<delete>

Delete a user from a group, or if no user name is given,
delete the group and all the users within it.

If additional arguments are given and the group name is equal to the uid:
Delete user information specified by the arguments (keys and values)


=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::API::Group->delete();
# Purpose    : Delete a user in a group or the whole group
# Returns    : The result of the request as XML string
# Parameters : none
# Throws     : no exceptions
# Comments   : Overwrites delete method from parent

sub delete {
    my $self = shift;

    my $message    = '';
    my $group_name = $self->{path_elements}[0];
    my $user_name  = $self->{path_elements}[1];
    my $uid        = $self->{args}->{uid};

    # Add user info if more than one argument is given and gid=uid
    if ((scalar keys %{$self->{args}} > 1) && ($group_name eq $uid)){
        my %data = %{$self->{args}};
        delete $data{uid};
        &LetsMT::Repository::GroupManager::del_user_info( $uid, %data );
        $message = "Delete user info for user '$uid'";
    }
    else{
        &LetsMT::Repository::GroupManager::delete_group( \$message, $uid,
           $group_name, $user_name, );
    }

    # Success if we got here, prepare Result object and return it
    my $result_obj = LetsMT::Repository::Result->new(
        type      => 'ok',
        code      => 0,
        operation => 'DELETE',
        location  => $self->{path_info},
        message   => $message,
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