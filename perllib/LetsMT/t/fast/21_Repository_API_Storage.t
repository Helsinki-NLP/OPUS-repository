#!/usr/bin/perl
#-*-perl-*-

=head1 NAME

21_Repository_API_Storage.t - test I<Storage> API

=head1 DESCRIPTION

This script tests the following assertions:

Calling the I<Storage> API via the C<WebService> module, ...

=over 2

=cut


use strict;
use warnings;

use open qw(:std :locale);

use FindBin qw($Bin);
use lib ("$Bin/../../lib", "$Bin/..");

use Scaffold;
use Test::More;
use XML::LibXML;
use File::Compare;
use File::Slurp;

use LetsMT::WebService;
use LetsMT::Resource;

# Prepare test data
my $id     = int( rand(999999999999) );
my $slot_1 = 'slot_name_1_' . $id;

$id = int( rand(999999999999) );
my $slot_2 = 'slot_name_2_' . $id;
my $file_2 = 'test_file_2_' . $id . '.txt';

my ($uid_1, $gid_1) = Scaffold::add_user;
my ($uid_2, $gid_2) = Scaffold::add_user;

my $tmpdir = Scaffold::tempdir;

my $backend_type = shift(@ARGV) || $ENV{VC_BACKEND};

#############################################################################
# POSITIVE TESTS
#############################################################################

=item *

you can create a slot with a branch. (put)

=cut

my $resource = new LetsMT::Resource(
    slot => $slot_1,
    user => $uid_1,
);
my $result = LetsMT::WebService::put(
    $resource->path_down,
    uid => $uid_1,
    gid => $gid_1,
    type => $backend_type
);
is( $result, 1, "PUT storage, create $backend_type slot_1 with user uid_1" );


=item *

you can read the branch ... (get)

=cut

$result = LetsMT::WebService::get(
    $resource->path_down,
    uid => $uid_1,
);
#print $result->decoded_content;
my $expected_status = {
    type      => 'ok',
    code      => 0,
    operation => 'GET',
    location  => "/storage/$slot_1/$uid_1",
};
is_deeply( xml_to_hash( $result ), $expected_status,
    "GET storage, list newly created slot/branch, check status"
);


=item *

... and the result will show the branch.

=cut

my $dom = xml_to_dom( $result );
ok( $dom->exists( '//list[@path="/' . $slot_1 . '/' . $uid_1 . '"]' ),
    '- check content: branch exists'
);


=item *

you can also read the slot ... (get)

=cut

$resource = new LetsMT::Resource(
    slot => $slot_1,
);
$result = LetsMT::WebService::get(
    $resource->path_down,
    uid => $uid_1,
);
$expected_status = {
    type      => 'ok',
    code      => 0,
    operation => 'GET',
    location  => "/storage/$slot_1",
};
is_deeply( xml_to_hash( $result ), $expected_status,
    "GET storage, list slot created above, check status"
);


=item *

... and the result will show the slot ...

=cut

$dom = xml_to_dom( $result );
ok( $dom->exists( '//list[@path="/' . $slot_1 . '"]' ),
    '- check content: slot exists'
);


=item *

...and that it contains the branch created above, ...

=cut

ok( $dom->exists( qq(//list[\@path="/$slot_1"]/entry[\@kind="branch"]) ),
    '- check content: branch exists'
);


=item *

... whose name, owner and group are as specified.

=cut

is( $dom->findnodes( qq(//list[\@path="/$slot_1"]/entry/name) )->to_literal,
    $uid_1,
    '- check content: branch name'
);
is( $dom->findnodes( qq(//list[\@path="/$slot_1"]/entry/owner) )->to_literal,
    $uid_1,
    '- check content: branch owner'
);
is( $dom->findnodes( qq(//list[\@path="/$slot_1"]/entry/group) )->to_literal,
    $gid_1,
    '- check content: branch group'
);


#############################################################################
# Create another slot

$resource = new LetsMT::Resource(
    slot => $slot_2,
    user => $uid_2,
);
LetsMT::WebService::put(
    $resource->path_down,
    uid => $uid_2,
    gid => $gid_2,
    type => $backend_type
);


=item *

you can upload a file to an existing branch. (put_file)

=cut

$resource = new LetsMT::Resource(
    slot => $slot_2,
    user => $uid_2,
    path => 'uploads/' . $file_2,
);
$result = LetsMT::WebService::put_file(
    $resource,
    "$Bin/data/test.txt",
);
is( $result, 1, "PUT storage, upload a test file via put" );


=item *

you can see the file in the branch listing ... (get)

=cut

$resource = new LetsMT::Resource(
    slot => $slot_2,
    path => "$uid_2/uploads",
);
$result   = LetsMT::WebService::get(
    $resource,
    uid => $uid_2,
);
$expected_status = {
    type      => 'ok',
    code      => 0,
    operation => 'GET',
    location  => "/storage/$slot_2/$uid_2/uploads",
};
is_deeply( xml_to_hash( $result ), $expected_status,
    "GET storage, list previously uploaded file in slot_2/uid_2, check status"
);


=item *

... and the file name and author name are correct.

=cut

$dom = xml_to_dom( $result );
ok( $dom->exists( qq(//list[\@path="/$slot_2/$uid_2/uploads"]/entry[\@kind="file"]) ),
    '- check content: slot_2/uid_2/uploads path exists'
);
is( $dom->findnodes('//entry/name')->to_literal,
    $file_2, '- check content: file name'
);
is( $dom->findnodes('//entry/commit/author')->to_literal,
    $uid_2, '- check content: author name'
);


=item *

you can download the previously uploaded file ... (get_resource)

=cut

$resource = new LetsMT::Resource(
    slot      => $slot_2,
    user      => $uid_2,
    path      => "uploads/$file_2",
    local_dir => $tmpdir,
);
$result = LetsMT::WebService::get_resource( $resource, uid => $uid_2 );
is( $result, 1,
    "DOWNLOAD storage, download of slot_2/uid_2/uploads/file_2, status"
);
ok( -f "$tmpdir/uploads/$file_2", "- check content: downloaded file_2 exists" );


=item *

... and its content matches that of the original file.

=cut

is( compare( "$Bin/data/test.txt", "$tmpdir/uploads/$file_2" ),
    0, "- check content: content of uploaded and downloaded file match"
);


=item *

you can get (cat) the content of the uploaded file ... (get)

=cut

$resource = new LetsMT::Resource(
    slot      => $slot_2,
    user      => $uid_2,
    path      => "uploads/$file_2",
    local_dir => $tmpdir,
);
$result   = LetsMT::WebService::get(
    $resource,
    uid    => $uid_2,
    action => 'cat'
);


=item *

... and it, too, matches the original content.

=cut

$dom = xml_to_dom( $result );
my $original = read_file( "$Bin/data/test.txt" ) ;
is( $dom->findnodes( qq(//list[\@path="/$slot_2/$uid_2/uploads/$file_2"]/entry) )->to_literal,
    $original,
    'GET storage, cat of slot_2/uid_2/uploads/file_2, check content'
);


=item *

you can delete a previously created slot,
(including its metadata, but we don't test that here) ... (del)

=cut

$resource = new LetsMT::Resource( slot => $slot_1 );
$result = LetsMT::WebService::del(
    $resource->path_down,
    uid => $uid_1,
    action => 'delete_meta'
);
is( $result, 1, "DELETE storage, delete slot_1" );


=item *

... and then the slot is really gone.

=cut

$result = LetsMT::WebService::get(
    $resource->path_down,
    uid => $uid_1
);
$expected_status = {
    type      => 'error',
    code      => 6,
    operation => 'GET',
    location  => "/storage/$slot_1",
};
is_deeply( xml_to_hash( $result ), $expected_status,
    "GET storage, try to list slot_1 deleted in previous step, check status"
);


=item *

you can copy a branch within a slot ... (copy)

=cut

$resource = new LetsMT::Resource(
    slot   => $slot_2,
    branch => $uid_2,
    user   => $uid_2,
);
my ($uid_3, $gid_3) = Scaffold::add_user;
my $dest = $uid_3;  # destination = user uid_3
# add user 'uid_3' to group 'gid_2' (owned by user 'uid_2')
# --> uid_3 gets read permissions for branch slot_2/uid_2
$result = LetsMT::WebService::put_group( $gid_2, $uid_3, $uid_2 );

# copy branch slot_2/uid_2 to slot_2/dest (dest = uid_3)
$result = &LetsMT::WebService::copy( $resource, $uid_3, $dest );
is( $result, 1, "POST copy branch_2 to branch_3, check status" );


=item *

... and then it does exist at the new location,
with the correct owner and group set.

=cut

$resource = new LetsMT::Resource(
    slot => $slot_2,
    path => $uid_3,
);
$result   = LetsMT::WebService::get(
    $resource->path_down,
    uid => $uid_2,
);
$dom = xml_to_dom( $result );
ok( $dom->exists( qq(//list[\@path="/$slot_2"]/entry[\@kind="branch"]/name["$uid_3"]) ),
    '- check content: branch name'
);
ok( $dom->exists( qq(//list[\@path="/$slot_2"]/entry[\@kind="branch"]/owner["$uid_3"]) ),
    '- check content: branch owner'
);
ok( $dom->exists( qq(//list[\@path="/$slot_2"]/entry[\@kind="branch"]/group["$gid_3"]) ),
    '- check content: branch group'
);


#############################################################################
# NEGATIVE TESTS
#############################################################################

=item *

you CANNOT access a branch if you do not belong to the correct group. (get)

=cut

$resource = new LetsMT::Resource( slot => $slot_2, user => $uid_2 );
$result   = LetsMT::WebService::get( $resource->path_down, uid => $uid_1 );
$expected_status = {
    type      => 'error',
    code      => 6,
    operation => 'GET',
    location  => "/storage/$slot_2/$uid_2",
};
is_deeply( xml_to_hash( $result ), $expected_status,
    "! GET storage, try to list slot_2/user_2 with active user 'user_1', check status"
);


=item *

you CANNOT list all slots without specifying a user ID. (get)

=cut

$resource = new LetsMT::Resource( slot => '' );
$result   = LetsMT::WebService::get( $resource->path_down );
$expected_status = {
    type      => 'error',
    code      => 12,
    operation => 'GET',
    location  => "/storage/",
};

is_deeply( xml_to_hash( $result ), $expected_status,
    "! GET storage, try to list all slots without user ID, check status"
);


=item *

you CANNOT delete a slot while there is still a branch belonging to another user. (del)

=cut

$resource = new LetsMT::Resource( slot => $slot_2 );
$result = LetsMT::WebService::del(
    $resource->path_down,
    uid    => $uid_2,
    action => 'delete_meta',
);
is( $result, '', "! DELETE storage, try to delete slot_2 while branch 'uid_3' still exists" );


#############################################################################
# CLEAN UP
#############################################################################

sub cleanup
{

=item *

you can delete a branch you own from a slot created by another user. (del)

=cut

    $resource = new LetsMT::Resource( slot => $slot_2, path => $uid_3 );
    $result = LetsMT::WebService::del(
        $resource,
        uid    => $uid_3,
        action => 'delete_meta'
    );
    is( $result, 1, "DELETE storage, delete branch 'uid_3' in 'slot_2'" );


=item *

you can delete a slot once all other users' branches in it are gone. (del)

=cut

    $resource = new LetsMT::Resource( slot => $slot_2 );
    $result = LetsMT::WebService::del(
        $resource->path_down,
        uid    => $uid_2,
        action => 'delete_meta',
    );
    is( $result, 1, "DELETE storage, delete slot_2" );

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
