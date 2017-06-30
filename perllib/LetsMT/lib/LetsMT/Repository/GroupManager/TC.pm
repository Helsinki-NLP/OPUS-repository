package LetsMT::Repository::GroupManager;

=head1 NAME

LetsMT::Repository::GroupManager - a group manager

=head1 DESCRIPTION

This is the group manager API. Using sub modules directly is no-no.

=cut

use strict;

use open qw(:std :utf8);

use Data::Dumper;
use Log::Log4perl qw(get_logger :levels);
use LetsMT::Repository::Err qw/ raise /;
use LetsMT::Repository::GroupManager::GroupDB;

#####################################################
#### PUBLIC CLASS METHODS ###########################
#####################################################

=head1 METHODS

=head2 C<drop_tables>

Use with care!

=cut

#### Clean out the database. Use with care...
sub drop_tables {
    my $GroupDB = new LetsMT::Repository::GroupManager::GroupDB;
    $GroupDB->delete_all();
}


=head2 C<create_group>

=cut

#### Creates a Group object or raises exception
# creating a user is equal to creating a group as every user is automatically
# added his own group that has the name of the user name. The user is also
# added to the group 'public' and to the group $GroupName if that one isn't
# eq to 'public' or the users name.
sub create_group {
    my ( $GroupName, $uid ) = @_;

    # Check if group name and uid are set
    raise( 12, 'group name', 'warn' ) unless ($GroupName);
    raise( 12, 'uid',        'warn' ) unless ($uid);

    my $GroupDB = new LetsMT::Repository::GroupManager::GroupDB;

    # check if the group exists already
    my $group = $GroupDB->get($GroupName);
    if ( exists $group->{owner} && $GroupName ne 'public' ) {
        raise( 4, "group '$GroupName'", 'warn' );    # Group exists already
    }

    # TODO: is this safe enough or can there be racing conditions?
    # (check if TokyoCabinet really locks the database when opening
    #  for writing!)

    # If $GroupName is not 'public' or $uid, create user in group $GroupName
    # this prevents double addition to these groups later on
    if ( $GroupName ne 'public' && $GroupName ne $uid ) {

        if (!$GroupDB->post( $GroupName, { member => $uid, owner => $uid } ) )
        {
            raise( 10, "'$GroupName' as user '$uid'", 'warn' )
                ;    #Failed to create group...
        }
    }

    # Add user to newly created group $uid
    if ( !$GroupDB->post( $uid, { member => $uid, owner => $uid } ) ) {
        raise( 10, "'$GroupName' as user '$uid'", 'warn' );
    }

    # Add user $uid to group 'public' owned by 'admin'
    # If group 'public' doesn't exist yet it will be created now
    if ( !$GroupDB->put( 'public', { member => $uid, owner => 'admin' } ) ) {
        raise( 10, "'$GroupName' as user '$uid'", 'warn' );
    }
}


=head2 C<delete_group>

=cut

#### Delete group
sub delete_group {
    my ( $message, $uid, $group, $user ) = @_;

    # Check if group name and uid are set
    raise( 12, 'group name', 'warn' ) unless ($group);
    raise( 12, 'uid',        'warn' ) unless ($uid);

    my $GroupDB = new LetsMT::Repository::GroupManager::GroupDB;

    my $data = $GroupDB->get($group);
    unless ( exists $data->{owner} ) {
        raise( 3, $group, 'warn' );    # Group not found
    }
    unless ( $data->{owner} eq $uid ) {
        raise(
            14,
            $uid
                . ", Effective user '$uid' must be owner of group '$group'"
                . " (owner: "
                . $data->{owner} . ")",
            'warn'
        );
    }

    # If a user was given, that one will be deleted...
    if ( defined($user) ) {
        if ( $GroupDB->is_member( $user, $data ) ) {
            $GroupDB->delete( $group, 'member', $user );
            $$message = "Deleted user '$user' from group '$group'";
        }
        else {
            raise( 15, $user, 'warn' );    # Not a valid user
        }
    }
    else {    # otherwise the group will be deleted
        $GroupDB->delete($group);
        $$message = "Deleted group '$group'";
    }
}


=head2 C<delete_user_recursive>

=cut

#### Delete user recursively from all groups
sub delete_user_recursive {
    my ( $message, $user ) = @_;

    my $sub_message = undef;
    my $group       = undef;

    # Check if user name and uid are set
    raise( 12, 'user name', 'warn' ) unless ($user);

    my $GroupDB = new LetsMT::Repository::GroupManager::GroupDB;

    my $groups = &get_groups_for_user($user);

    # Delete $user from all groups he is member of
    foreach $group (@$groups) {
        my $data = $GroupDB->get($group);
        get_logger(__PACKAGE__)
            ->debug("Deleting user '$user' from group '$group'");
        &delete_group( \$sub_message, $data->{owner}, $group, $user );
        $$message .= $sub_message . ', ';
    }

    # Delete all groups $user is owner of
    my $owned_groups = $GroupDB->search( { 'ALL_OF_owner' => $user } );
    get_logger(__PACKAGE__)->debug( 'owner of: ' . Dumper($owned_groups) );
    foreach $group (@$owned_groups) {
        get_logger(__PACKAGE__)
            ->debug("Deleting group '$group' owned by '$user'");
        &delete_group( \$sub_message, $user, $group );
        $$message .= $sub_message . ', ';
    }
}


=head2 C<get_group>

=cut

sub get_group {
    my $GroupName = shift;
    my $GroupDB   = new LetsMT::Repository::GroupManager::GroupDB;
    if ($GroupName) {
        return $GroupDB->get($GroupName);
    }
    return {};
}


=head2 C<group_exists>

=cut

sub group_exists {
    my $group = get_group( $_[0] );
    return exists $group->{owner};
}


=head2 C<read_group>

 $xml = $gm->read_group ($gid)

Search for group C<$gid> and return all users in it, if any.

=cut

### METHOD ##################################################################
# Usage      : LetsMT::Repository::GroupManager->read_group( [STRING] );
# Purpose    : Searches for $group and returns all users in it, if any
# Returns    : String in XML format
# Parameters : $group
# Throws     : no exceptions
# Comments   : Search with empty group name returns all groups and their uers

sub read_group {
    my $result = shift;
    my @groups = @_;

    my $GroupDB = new LetsMT::Repository::GroupManager::GroupDB;

    # if no group is given or an empty strings is given: get all groups
    if ( ( not @groups ) || ( $groups[0] eq '' ) ) {
        @groups = $GroupDB->get_all_groups();
    }

    my $entries = [];
    foreach my $g (@groups) {
        my $group = $GroupDB->get($g);
        unless ( exists $group->{owner} ) {
            raise( 3, $g, 'warn' );    # Group not found
        }
        my @members = $GroupDB->members($group);
        push(
            @$entries,
            {   'kind'  => 'group',
                'id'    => $g,
                'user'  => \@members,
                'owner' => $group->{owner}
            }
        );
    }

    # Build hash ref for result
    $$result = {
        'path'  => '/group/',
        'entry' => $entries,
    };
    return 1;
}


=head2 C<add_user_to_group>

=cut

#### Update group
sub add_user_to_group {
    my ( $GroupName, $user, $uid ) = @_;

    my $logger = get_logger(__PACKAGE__);

    unless ($GroupName) { raise( 12, 'group name', 'warn' ); }
    unless ($user)      { raise( 12, 'user name',  'warn' ); }

    my $GroupDB = new LetsMT::Repository::GroupManager::GroupDB;

    my $group = $GroupDB->get($GroupName);
    unless ( exists $group->{owner} ) {
        raise( 3, $GroupName, 'warn' );    # Group not found
    }
    unless ( $group->{owner} eq $uid ) {
        raise(
            14,
            "$uid, Effective user must be owner of group '$GroupName'"
            . " (owner: " . $group->{owner} . ")",
            'warn'
        );
    }

    if ( $GroupDB->is_member( $user, $group ) ) {
        raise( 1, $user, 'warn' );    # User already a member of group
    }

    $GroupDB->put( $GroupName, { member => $user } )
        || raise( 2, $user, 'warn' );
    $logger->info("Created user '$user' in group '$GroupName'");
}


=head2 C<is_member>

=cut

sub is_member {
    my $GroupDB = new LetsMT::Repository::GroupManager::GroupDB;
    return $GroupDB->is_member(@_);
}


=head2 C<get_users_in_group>

=cut

# return a list of users (members of the given group)
sub get_users_in_group {
    my ($GroupName) = @_;

    my $GroupDB = new LetsMT::Repository::GroupManager::GroupDB;
    my $group   = $GroupDB->get($GroupName);
    return $GroupDB->members($group);
}


=head2 C<get_groups_for_user>

=cut

#### Returns a Groupmember object or false.
sub get_groups_for_user {
    my ($user) = @_;
    my $GroupDB = new LetsMT::Repository::GroupManager::GroupDB;
    my $groups = $GroupDB->search( { 'ALL_OF_member' => $user } );
    return $groups;
}


=head2 C<get_user_info>

Get information about a given user.
Returns a reference to a hash with key-value pairs.

=cut


sub get_user_info{
    my $user = shift;
    my $GroupDB = new LetsMT::Repository::GroupManager::GroupDB;
    my $info = $GroupDB->get($user) || {};
    my $groups = get_groups_for_user($user);
    if (ref($groups) eq 'ARRAY'){
        $$info{member_of} = join(',',@$groups);
    }
    delete $$info{owner};
    $$info{my_group} = $$info{member} if (exists $$info{member});
    return $info;
}


=head2 C<set_user_info>

Set user information in terms of key-value pairs.
User information will be stored in the user's group.
This function overwrites existing values.

=cut

sub set_user_info{
    my $user = shift;
    my %data = @_;

    my $GroupDB = new LetsMT::Repository::GroupManager::GroupDB;
    return $GroupDB->post( $user, \%data );
}


=head2 C<add_user_info>

Add user information in terms of key-value pairs.
User information will be stored in the user's group.
Existing values will stay in the database.

=cut

sub add_user_info{
    my $user = shift;
    my %data = @_;

    my $GroupDB = new LetsMT::Repository::GroupManager::GroupDB;
    return $GroupDB->put( $user, \%data );
}


=head2 C<del_user_info>

Delete information about a specific user from the User's group database.
The given hash specifies keys and values to be deleted. Undefined values
or '*' cause the entire key to be deleted.
With an empty hash, the entire record will be deleted (don't do it!)

=cut

sub del_user_info{
    my $user = shift;
    my %data = @_;

    my $GroupDB = new LetsMT::Repository::GroupManager::GroupDB;
    return $GroupDB->delete( $user, %data );
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