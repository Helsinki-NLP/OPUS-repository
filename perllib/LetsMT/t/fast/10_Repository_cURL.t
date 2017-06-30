#!/usr/bin/perl
#-*-perl-*-

=head1 NAME

10_Repository_cURL.t - test raw Web-API access

=head1 DESCRIPTION

This script tests the following assertions:

Using 'raw' access to the Web APIs via C<cURL> calls, ...

=over 2

=cut


use strict;
use warnings;

use open qw(:std :locale);

use FindBin qw($Bin);
use lib ("$Bin/../../lib", "$Bin/..");
$ENV{PATH} = "$Bin/../../bin:$ENV{PATH}";

use Scaffold;
use Test::More;


my $host = $ENV{LETSMT_URL};

# Prepare test data
my $id     = int( rand(999999999999) );
my $gid_1  = 'group_id_1_' . $id;
my $uid_1  = 'user_id_1_' . $id;
my $slot_1 = 'slot_name_1_' . $id;


$id = int( rand(999999999999) );
my $gid_2  = 'group_id_2_' . $id;
my $uid_2  = 'user_id_2_' . $id;
my $slot_2 = 'slot_name_2_' . $id;
my $file_2 = 'test_file_2_' . $id . '.txt';


#############################################################################
# POSITIVE TESTS
#############################################################################

=item *

you can create a group with a user. (API: POST group)

=cut

my $result = `$ENV{LETSMT_CONNECT_RAW} -X POST '$host/group/$gid_1/$uid_1?uid=$uid_1'`;
my $status_hash     = xml_to_hash( $result );
my $expected_status = {
    type      => 'ok',
    code      => 0,
    operation => 'POST',
    location  => "/group/$gid_1/$uid_1",
};
is_deeply( $status_hash, $expected_status,
    "POST create group 'gid_1' with user 'uid_1', check status"
);


=item *

you can create a slot with a user branch. (POST storage)

=cut

$result = `$ENV{LETSMT_CONNECT_RAW} -X POST '$host/storage/$slot_1/$uid_1?uid=$uid_1&gid=$gid_1'`;
$status_hash     = xml_to_hash( $result );
$expected_status = {
    type      => 'ok',
    code      => 0,
    operation => 'POST',
    location  => "/storage/$slot_1/$uid_1",
};
is_deeply( $status_hash, $expected_status,
    "POST create slot 'slot_1' with user branch 'uid_1', check status"
);


=item *

you can upload a file. (PUT storage)

=cut

$result = `$ENV{LETSMT_CONNECT_RAW} -F payload=data/tmx/small.tmx -X PUT '$host/storage/$slot_1/$uid_1/file.tmx?uid=$uid_1'`;
$status_hash     = xml_to_hash( $result );
$expected_status = {
    type      => 'ok',
    code      => 0,
    operation => 'PUT',
    location  => "/storage/$slot_1/$uid_1/file.tmx",
};
is_deeply( $status_hash, $expected_status,
    "PUT upload a file 'file.tmx' to 'slot_1/uid_1', check status"
);


=item *

you can list the content of a slot/branch ... (GET storage)

=cut

$result = `$ENV{LETSMT_CONNECT_RAW} -X GET '$host/storage/$slot_1/$uid_1?uid=$uid_1'`;
$status_hash     = xml_to_hash( $result );
$expected_status = {
    type      => 'ok',
    code      => 0,
    operation => 'GET',
    location  => "/storage/$slot_1/$uid_1",
};
is_deeply( $status_hash, $expected_status,
    "GET list slot 'slot_1' with user branch 'uid_1', check status"
);

=item *

... and you can see the file saved there.

=cut

my $dom = xml_to_dom( $result );
is( $dom->findnodes( '//list[@path="/' . $slot_1 . '/' . $uid_1 . '"]/entry/name' )->to_literal,
    'file.tmx',
    '- check content: slot_1/uid_1/file.tmx exists'
);


# TODO: List metadata

# TODO: Download file


#############################################################################
# TODO: NEGATIVE TESTS
#############################################################################


#############################################################################
# CLEAN UP
#############################################################################

sub cleanup
{

=item *

you can delete a slot.

=cut

    my $result = `$ENV{LETSMT_CONNECT_RAW} -X DELETE '$host/storage/$slot_1?uid=$uid_1&gid=$gid_1'`;
    my $status_hash     = xml_to_hash( $result );
    my $expected_status = {
        type      => 'ok',
        code      => 0,
        operation => 'DELETE',
        location  => "/storage/$slot_1",
    };
    is_deeply( $status_hash, $expected_status, "DELETE slot 'slot_1', check status" );


=item *

you can delete a group. (DELETE group)

=cut

    $result = `$ENV{LETSMT_CONNECT_RAW} -X DELETE '$host/group/$gid_1?uid=$uid_1'`;
    $status_hash     = xml_to_hash( $result );
    $expected_status = {
        type      => 'ok',
        code      => 0,
        operation => 'DELETE',
        location  => "/group/$gid_1",
    };
    is_deeply( $status_hash, $expected_status, "DELETE group 'gid_1', check status" );


=item *

you can delete a user. (DELETE group)

=cut

    $result = `$ENV{LETSMT_CONNECT_RAW} -X DELETE '$host/group/$uid_1?uid=$uid_1'`;
    $status_hash     = xml_to_hash( $result );
    $expected_status = {
        type      => 'ok',
        code      => 0,
        operation => 'DELETE',
        location  => "/group/$uid_1",
    };
    is_deeply( $status_hash, $expected_status, "DELETE user 'uid_1', check status" );


=item *

you can delete a user from the I<public> group. (DELETE group)

=cut

    $result = `$ENV{LETSMT_CONNECT_RAW} -X DELETE '$host/group/public/$uid_1?uid=admin'`;
    $status_hash     = xml_to_hash( $result );
    $expected_status = {
        type      => 'ok',
        code      => 0,
        operation => 'DELETE',
        location  => "/group/public/$uid_1",
    };
    is_deeply( $status_hash, $expected_status, "DELETE user 'uid_1' from 'public', check status" );

    # Delete group, user group, & user from public (2)
    `$ENV{LETSMT_CONNECT_RAW} -X DELETE '$host/group/$gid_2?uid=$uid_2'`;
    `$ENV{LETSMT_CONNECT_RAW} -X DELETE '$host/group/$uid_2?uid=$uid_2'`;
    `$ENV{LETSMT_CONNECT_RAW} -X DELETE '$host/group/public/$uid_2?uid=admin'`;

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