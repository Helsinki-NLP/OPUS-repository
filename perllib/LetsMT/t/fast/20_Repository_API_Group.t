#!/usr/bin/perl
#-*-perl-*-

=head1 NAME

20_Repository_API_Group.t - test I<Group> API

=head1 DESCRIPTION

This script tests the following assertions:

Calling the I<Group> API via the C<WebService> module, ...

=over 2

=cut


use strict;
use warnings;

use open qw(:std :locale);

use FindBin qw($Bin);
use lib ("$Bin/../../lib", "$Bin/..");

use Scaffold;
use Test::More;

use LetsMT::WebService;

# Prepare test data
my $id     = int( rand(999999999999) );
my $gid_1  = 'group_id_1_'  . $id;
my $uid_1  = 'user_id_1_'   . $id;
my $user_1 = 'user_name_1_' . $id;

$id = int( rand(999999999999) );
my $gid_2  = 'group_id_2_'  . $id;
my $uid_2  = 'user_id_2_'   . $id;
my $user_2 = 'user_name_2_' . $id;


#############################################################################
# POSITIVE TESTS
#############################################################################

=item *

you can create groups with users in them. (post_group)

=cut

my $result = LetsMT::WebService::post_group( $gid_1, undef, $uid_1 );
is( $result, 1, "POST group, create group_1 with user uid_1" );

$result = LetsMT::WebService::post_group( $gid_2, undef, $uid_2 );
is( $result, 1, "POST group, create group_2 with user uid_2" );


=item *

you can list a group ... (get_group)

=cut

$result = LetsMT::WebService::get_group( $gid_1, undef, $uid_1 );
my $expected_status = {
    type      => 'ok',
    code      => 0,
    operation => 'GET',
    location  => "/group/$gid_1",
};
is_deeply( xml_to_hash( $result ), $expected_status,
    "GET group, request group_1 created in previous step, check status"
);


=item *

... and you can see the users that are in the group.

=cut

my $dom = xml_to_dom( $result );
ok( $dom->exists( '//entry[@id="' . $gid_1 . '"][@kind="group"]' ),
    '- check content: group_1 exists'
);
ok( $dom->exists( '//entry[@id="' . $gid_1 . '"][@kind="group"][user="' . $uid_1 . '"]' ),
    '- check content: user uid_1 exists in group_1'
);


=item *

you can add a user to an existing group. (put_group)

=cut

$result = LetsMT::WebService::put_group( $gid_1, $user_2, $uid_1 );
is( $result, 1, "PUT group, add user_2 to existing group_1" );


=item *

you can list all existing groups and users ... (get_group with undefined GID)

=cut

$result = LetsMT::WebService::get_group( undef, undef, $uid_1 );
$expected_status = {
    type      => 'ok',
    code      => 0,
    operation => 'GET',
    location  => "/group/",
};
is_deeply( xml_to_hash( $result ), $expected_status,
    "GET group, list all existing groups and user, check status"
);


=item *

... and the result is accurate.

=cut

$dom = xml_to_dom( $result );
ok( $dom->exists( '//entry[@id="' . $gid_1 . '"][@kind="group"]' ),
    '- check content: group_1 exists'
);
ok( $dom->exists( '//entry[@id="' . $gid_1 . '"][@kind="group"][user="' . $uid_1 . '"]' ),
    '- check content: user uid_1 exists in group_1'
);
ok( $dom->exists( '//entry[@id="' . $gid_2 . '"][@kind="group"][user="' . $uid_2 . '"]' ),
    '- check content: user uid_2 exists in group_2'
);
ok( $dom->exists( '//entry[@id="' . $gid_1 . '"][@kind="group"][user="' . $user_2 . '"]' ),
    '- check content: user user_2 exists in group_1'
);


=item *

you can delete a user from a group ... (del_group)

=cut

$result = LetsMT::WebService::del_group( $gid_1, $user_2, $uid_1 );
is( $result, 1, "DELETE group, delete user_2 from group_1" );


=item *

... and afterwards that user is actually gone from the group.

=cut

$result = LetsMT::WebService::get_group( $gid_1, undef, $uid_1 );
$dom    = xml_to_dom( $result );
ok( ! $dom->exists( '//entry[@id="' . $gid_1 . '"][@kind="group"][user="' . $user_2 . '"]' ),
    'GET group, check that previously deleted user_2 is gone in group_1'
);


=item *

you can delete a group ... (del_group with undefined UID)

=cut

$result = LetsMT::WebService::del_group( $gid_1, undef, $uid_1 );
is( $result, 1, "DELETE group_1" );


=item *

... and afterwards that user is actually gone.

=cut

$result = LetsMT::WebService::get_group( $gid_1, undef, $uid_1 );
$dom = xml_to_dom( $result );
ok( ! $dom->exists( '//entry[@id="' . $gid_1 . '"][@kind="group"]' ),
    'GET group, check that previously deleted group_1 is gone'
);


#############################################################################
# NEGATIVE TESTS
#############################################################################

=item *

you CANNOT find a group that does not exist. (get_group)

=cut

$result = LetsMT::WebService::get_group( $gid_1, undef, $uid_1 );
$expected_status = {
    type      => 'error',
    code      => 3,
    operation => 'GET',
    location  => "/group/$gid_1",
};
is_deeply( xml_to_hash( $result ), $expected_status,
    "GET group, request group that does not exist"
);


=item *

you CANNOT add a user that already exists in a group. (put_group)

=cut

$result = LetsMT::WebService::put_group( $gid_2, $uid_2, $uid_2 );
ok( ! $result,
    "PUT group, Try to add user uid_2 that already exists in group_2"
);


=item *

you CANNOT add a user to a group if you specify the wrong owner UID. (put_group)

=cut

$result = LetsMT::WebService::put_group( $gid_1, $user_2, $uid_2 );
ok( ! $result, "PUT group, try to add user_2 with wrong uid (uid_2 not creator of group_1)" );


=item *

you CANNOT delete a user from a group if it isn't a member. (del_group)

=cut

$result = LetsMT::WebService::del_group( $gid_2, $user_1, $uid_2 );
ok( ! $result, "DELETE group, try to delete user_1 that does not exist in group_2" );


#=item *
#
#you CANNOT delete a user from a group if you specify the wrong owner UID. (del_group)
#
#=cut


=item *

you CANNOT delete a group that does not exist. (del_group)

=cut

$result = LetsMT::WebService::del_group( $gid_1, undef, $uid_1 );
ok( ! $result, "DELETE group, try to delete group_1 that does not exist" );


=item *

you CANNOT delete a group if you specify the wrong owner UID. (del_group)

=cut

$result = LetsMT::WebService::del_group( $gid_2, undef, $uid_1 );
ok( ! $result, "DELETE group, try to delete group with wrong uid (uid not creator of group)" );


#############################################################################
# Clean up
#############################################################################

sub cleanup
{
    # Remove groups $gid_1 (for good measure), $gid_2
    LetsMT::WebService::del_group( $gid_1, undef, $uid_1 );
    LetsMT::WebService::del_group( $gid_2, undef, $uid_2 );

    # Remove groups $uid_1, $uid_2
    LetsMT::WebService::del_group( $uid_1, undef, $uid_1 );
    LetsMT::WebService::del_group( $uid_2, undef, $uid_2 );


=item *

you can delete a user from the group 'public'. (del_group)

=cut

    my $result = LetsMT::WebService::del_group( 'public', $uid_1, 'admin' );
    is( $result, 1, "DELETE uid_1 from group 'public'" );

    LetsMT::WebService::del_group( 'public', $uid_2, 'admin' );

    Scaffold::cleanup;
}

=back

=cut


&cleanup;

done_testing;


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