package LetsMT::Repository::GroupManager;

=head1 NAME

LetsMT::Repository::GroupManager - a group manager

=head1 DESCRIPTION

This is the group manager API. Using sub modules directly is no-no.

=cut

use strict;
use Data::Dumper;

use Log::Log4perl qw(get_logger :levels);
use LetsMT::Repository::Err qw/ raise /;
use LetsMT::Repository::GroupManager::Groupmember;
use LetsMT::Repository::GroupManager::Group;

#####################################################
#### PUBLIC CLASS METHODS ###########################
#####################################################

=head1 METHODS

=head2 C<drop_tables>

=cut

#### Clean out the database. Use with care...
sub drop_tables {
    LetsMT::Repository::GroupManager::Groupmember::drop_table();
    LetsMT::Repository::GroupManager::Group::drop_table();
}


=head2 C<create_group>

=cut

#### Creates a Group object or raises exception
sub create_group {
    my ( $group, $uid ) = @_;

    my $logger = get_logger(__PACKAGE__);

    # Check if group name and uid are set
    raise( 12, 'group name', 'warn' ) unless ($group);
    raise( 12, 'uid',        'warn' ) unless ($uid);

    # create also a user-specific group if necessary
    # and add the user to the public group (owned by 'admin')
    if ( $group ne 'public' && $group ne $uid ) {
        create_group( $uid,     $uid )    unless ( &group_exists($uid) );
        create_group( 'public', 'admin' ) unless ( &group_exists('public') );
        my $usergroups = &get_groups_for_user($uid);
        if ( !grep { $_ eq 'public' } @{$usergroups} ) {
            &add_user_to_group( 'public', $uid, 'admin' );
        }
    }

    # Create the new group
    my $obj = new LetsMT::Repository::GroupManager::Group( $group, $uid );

    # Add user $uid to the newly created group
    my $gmobj
        = new LetsMT::Repository::GroupManager::Groupmember( $uid, $group );

    if ( $obj && $gmobj ) {
        $obj->save();
        $gmobj->save();
    }
    else {
        raise( 10, "'$group' as user '$uid'", 'warn' );
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

    # Check if group exists
    my $groupobj = &get_group($group);
    unless ($groupobj) {
        raise( 3, $group, 'warn' );    # Group not found
    }

    # Check if user has right permissions
    unless ( $uid eq $groupobj->creator ) {
        raise(
            14,
            $uid
                . ", Effective user '$uid' must be owner of group '$group'"
                . " (owner: "
                . $groupobj->creator . ")",
            'warn'
        );
    }

    # If a user was given, that one will be deleted...
    if ( defined($user) && $user ) {
        my $groupmemberobj = &get_groupmember( $user, $group );
        if ($groupmemberobj) {
            $groupmemberobj->delete();
            $message = "Deleted user '$user'";
        }
        else {
            raise( 15, $user );    # Not a valid user
        }
    }
    else {                         # otherwise the group will be deleted
        $groupobj->delete();
        $message = "Deleted group '$group'";
    }
}


=head2 C<delete_user_recursive>

=cut

#### Delete user recursively from all groups
sub delete_user_recursive {
    my ( $message, $user ) = @_;

    # ... not implemented here ....
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
    my ( $result, $group ) = @_;

    my $groupobj = undef;

    # Search with empty group name returns all existing groups
    if ( !defined($group) || $group eq '' ) {
        $groupobj = &get_group('');
    }
    else {
        $groupobj = &get_group($group);
    }

    # If we got a result object, we found at least one matching group
    if ($groupobj) {
        my @grp = ();
        do { push( @grp, $groupobj->grp ) }
            while ( $groupobj->restore_next() );

        my $entries    = [];
        my $user_array = [];

        # For all found groups
        foreach my $group_name ( sort @grp ) {

            # Query for all users in the group
            my $groupmemberobj = &get_users_in_group($group_name);
            if ($groupmemberobj) {
                $user_array = undef;
                do { push( @$user_array, $groupmemberobj->user ) }
                    while ( $groupmemberobj->restore_next() );
            }

            push(
                @$entries,
                {   'kind' => 'group',
                    'id'   => $group_name,
                    'user' => $user_array,
                }
            );
        }

        # Build hash ref for result
        $$result = {
            'path'  => '/' . $group,
            'entry' => $entries,
        };

        return 1;
    }
    else {    # If we got no result object and...

        # ...but a group name was given means: the group doesn't exist
        if ( defined($group) && $group ne '' ) {
            raise( 3, $group, 'warn' );
        }
        else
        { # ...and no group name was given means: empty database or other error
                # TODO: what to do then?
            raise( 11, 'DB emtpy?', 'warn' );
        }
    }

}


=head2 C<add_user_to_group>

=cut

#### Update group
sub add_user_to_group {
    my ( $group, $user, $uid ) = @_;

    my $logger = get_logger(__PACKAGE__);

    unless ($group) { raise( 12, 'group name', 'warn' ); }
    unless ($user)  { raise( 12, 'user name',  'warn' ); }

    my $groupobj = &get_group($group);

    # Check if group exists
    unless ($groupobj) {
        raise( 3, $group, 'warn' );    # Group not found
    }

    # Check if user has permissions to add users to group
    unless ( $uid eq $groupobj->creator ) {
        raise(
            14,
            $uid
                . ", Effective user '$uid' must be owner of group '$group'"
                . " (owner: "
                . $groupobj->creator . ")",
            'warn'
        );
    }

    # Check for whitespace in user name (is that check realy needed?)
    unless ( $user =~ /^\S+$/ ) {
        raise( 11, "Supplied user looks suspicious: '$user'", 'warn' )
            ;    # Other error
    }

    # Check if user is already in group
    my $usergroups = &get_groups_for_user($user);
    $logger->info( 'Groups of user: ' . Dumper($usergroups) );
    if ( grep { $_ eq $group } @{$usergroups} ) {
        raise( 1, $user, 'warn' );    # User already a member of group
    }

    # If we get here, alls seems fine and we can create/add the user
    if ( new LetsMT::Repository::GroupManager::Groupmember( $user, $group ) )
    {
        $logger->info("Created user '$user' in group '$group'");
    }
    else {
        raise( 2, $user, 'warn' );    # Failed to add user to group
    }
}


=head2 C<group_exists>

=cut

sub group_exists {
    return 1 if ( &get_group( $_[0] ) );
    return 0;
}


###### CREATE/GET PERSISTENT OBJECTS ################

=head2 C<get_group>

=cut

#### Returns a Group object or false.
sub get_group {
    my $group_name = shift;
    my $idquery    = '';

    get_logger(__PACKAGE__)->debug( 'groupname: ' . $group_name );

    if ( defined $group_name && $group_name ne '' ) {
        $idquery = LetsMT::Repository::GroupManager::Group::get_idquery(
            $group_name);
    }

    get_logger(__PACKAGE__)->debug( 'query: ' . $idquery );

    my $obj = new LetsMT::Repository::GroupManager::Group();

    return &_get( $idquery, $obj );
}


=head2 C<get_groupmember>

=cut

#### Returns a Groupmember object or false.
sub get_groupmember {
    my ( $user, $group ) = @_;
    my $idquery
        = LetsMT::Repository::GroupManager::Groupmember::get_idquery( $user,
        $group );
    my $obj = new LetsMT::Repository::GroupManager::Groupmember();

    return &_get( $idquery, $obj );
}


=head2 C<get_users_in_group>

=cut

#### Returns a Groupmember object (with Persistent iterator) or false.
sub get_users_in_group {
    my ($group) = @_;
    my $idquery = LetsMT::Repository::GroupManager::Groupmember::get_idquery_users_in_group(
        $group
    );
    my $obj = new LetsMT::Repository::GroupManager::Groupmember();

    return &_get( $idquery, $obj );
}


=head2 C<get_groups_for_user>

=cut

#### Returns a Groupmember object or false.
sub get_groups_for_user {
    my ($user) = @_;
    my $idquery = LetsMT::Repository::GroupManager::Groupmember::get_idquery_groups_for_user(
        $user
    );
    my $obj = new LetsMT::Repository::GroupManager::Groupmember();
    ## always member of public & your own group
    my @groups = ();

    $obj = &_get( $idquery, $obj );
    if ( defined($obj) ) {
        do { push( @groups, $obj->grp ) } while ( $obj->restore_next() );
    }

    return \@groups;
}


## TODO: user info not implemented in mySQL version

sub get_user_info{}
sub set_user_info{}
sub add_user_info{}
sub del_user_info{}


=head1 INTERNAL METHOD

=head2 C<_get>

=cut

###### MISC METHODS ######

#### General persistent object retriever
#http://search.cpan.org/~dwinters/Persistent-Base-0.52/lib/Persistent.pod#Restoring_all_Objects
sub _get {
    my ( $idquery, $obj ) = @_;
    my $status = $obj->retrieve(qq{$idquery});

#  get_logger(__PACKAGE__)->debug("persist ".ref($obj).":$status   ($idquery)");
    return $status ? $obj : undef;
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