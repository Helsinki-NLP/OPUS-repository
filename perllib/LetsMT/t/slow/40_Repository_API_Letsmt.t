#!/usr/bin/perl
#-*-perl-*-

=head1 NAME

40_Repository_API_Letsmt.t - test I<Letsmt> API

=head1 DESCRIPTION

This script tests the following assertions:

Calling the I<Letsmt> API via the C<WebService> module, ...

=over 2

=cut


use strict;
use warnings;

use open qw(:std :locale);

use FindBin qw($Bin);
use lib ("$Bin/../../lib", "$Bin/..");

use Scaffold;
use Test::More;
use File::Compare;
use File::Temp;

use LetsMT::WebService;
use LetsMT::Repository::Result;
use LetsMT::Resource;

# Prepare test data
my $id     = int( rand(999999999999) );
my $slot_1 = 'slot_name_1_' . $id;

$id = int( rand(999999999999) );
my $slot_2 = 'slot_name_2_' . $id;
my $file_2 = 'test_file_2_' . $id;

my ($uid_1, $gid_1) = Scaffold::add_user;

my $tmpdir = Scaffold::tempdir;


#############################################################################
# POSITIVE TESTS
#############################################################################

=item *

you can create a slot with a (user) branch... (put_letsmt)

=cut

my $resource = new LetsMT::Resource( slot => $slot_1, user => $uid_1 );
my $result = LetsMT::WebService::put_letsmt(
    $resource->path_down,
    uid => $uid_1,
    gid => $gid_1,
);
is( $result, 1, "PUT letsmt, create slot_1 with branch 'uid_1'" );


=item *

you can look for the slot... (get_letsmt)

=cut

$result = LetsMT::WebService::get_letsmt(
    $resource->path_down,
    uid => $uid_1,
);
my $status_hash     = xml_to_hash( $result );
my $expected_status = {
    type      => 'ok',
    code      => 0,
    operation => 'GET',
    location  => "/letsmt/$slot_1",
};
is_deeply( $status_hash, $expected_status,
    "GET letsmt, list slot_1 created in previous step, check status"
);


=item *

... and the slot will exist.

=cut

my $dom = xml_to_dom( $result );
ok( $dom->exists( '//list[@path="/' . $slot_1 . '/' . $uid_1 . '"]' ),
    '- check content: slot_1 exists'
);


#############################################################################
# Create slot_2 with 'uid_2' and branch branch_2

my ($uid_2, $gid_2) = Scaffold::add_user;

$resource = new LetsMT::Resource( slot => $slot_2, user => $uid_2 );
$result   = LetsMT::WebService::put_letsmt(
    $resource->path_down,
    uid => $uid_2,
    gid => $gid_2
);
is( $result, 1, "PUT letsmt, create slot_2 with user uid_2 and branch_2" );

$resource = new LetsMT::Resource( slot => $slot_2 );
$result   = LetsMT::WebService::get_letsmt(
    $resource->path_down,
    uid => $uid_2,
);
$status_hash     = xml_to_hash( $result );
$expected_status = {
    type      => 'ok',
    code      => 0,
    operation => 'GET',
    location  => "/letsmt/$slot_2",
};
is_deeply( $status_hash, $expected_status,
    "GET letsmt, list slot_2 created in previous step, check status"
);

$dom = xml_to_dom( $result );
ok( $dom->exists( '//list[@path="/' . $slot_2 . '/' . $uid_2 . '"]' ),
    '- check content: slot_2 and branch uid_2 exists'
);


#############################################################################
# Upload a test file to slot_2, this also triggers the import of the file

$resource = new LetsMT::Resource(
    slot => $slot_2,
    user => $uid_2,
    path => '/uploads/txt/' . $file_2 . '.txt',
);
$result = LetsMT::WebService::put_letsmt_file( $resource, "$Bin/data/test.txt" );
is( $result, 1, "PUT letsmt, upload a test file via put" );

$resource = new LetsMT::Resource(
    slot => $slot_2,
    user => $uid_2,
    path => "/uploads/txt",
);
$result = LetsMT::WebService::get_letsmt( $resource, uid => $uid_2 );
$status_hash     = xml_to_hash( $result );
$expected_status = {
    type      => 'ok',
    code      => 0,
    operation => 'GET',
    location  => "/letsmt/$slot_2/uploads/txt",
};

is_deeply( $status_hash, $expected_status,
    "GET letsmt, list previously uploaded file in slot_2/uid_2, check status"
);

$dom = xml_to_dom( $result );
ok( $dom->exists(
              '//list[@path="/' 
            . $slot_2 . '/' 
            . $uid_2
            . '/uploads/txt"]/entry[@kind="file"]'
    ),
    '- check content: slot_2/uid_2/uploads/txt path exists'
);
ok( $dom->exists('//entry/name["'.$file_2.'.txt"]'),
    '- check content: file name'
);
ok( $dom->exists('//entry/name["'.$file_2.'.txt"]/../commit/author["'.$uid_2.'"]'),
    '- check content: author name'
);

#############################################################################
# Download the uploaded file and check its content

$resource = new LetsMT::Resource(
    slot      => $slot_2,
    user      => $uid_2,
    path      => "uploads/txt/$file_2.txt",
    local_dir => $tmpdir,
);
print $resource->local_path."\n";

$result = LetsMT::WebService::get_letsmt_resource(
    $resource,
    uid => $uid_2
);
is( $result, 1, "DOWNLOAD letsmt, download of slot_2/uid_2/txt/uploads/file_2, status" );
ok( -f "$tmpdir/uploads/txt/$file_2.txt", "- check content: downloaded file_2 exists" );
is( compare( "$Bin/data/test.txt", "$tmpdir/uploads/txt/$file_2.txt" ),
    0, "- check content: content of uploaded and downloaded file match"
);

#############################################################################
# Delete previously created branch 'uid_1' in slot_1

$resource = new LetsMT::Resource( slot => $slot_1, user => $uid_1 );
$result   = LetsMT::WebService::del_letsmt(
    $resource->path_down,
    uid => $uid_1,
);
is( $result, 1, "DELETE letsmt, delete branch 'uid_1' in slot_1" );

$result = LetsMT::WebService::get_letsmt(
    $resource->path_down,
    uid => $uid_1,
);
$status_hash     = xml_to_hash( $result );
$expected_status = {
    type      => 'error',
    code      => 6,
    operation => 'GET',
    location  => "/letsmt/$slot_1",
};

is_deeply( $status_hash, $expected_status,
    "GET letsmt, try to list branch deleted in previous step, check status"
);

#############################################################################
# Copy branch 2 'uid_2' to branch 3 'uid_3'

# Add user_3 to group_2, to get read access on slot_2/branch_2
my ($uid_3, $gid_3) = Scaffold::add_user;

$result = LetsMT::WebService::put_group( $gid_2, $uid_3, $uid_2 );
is( $result, 1, "PUT group, add user_3 to existing group_2" );

$resource = new LetsMT::Resource(
    slot   => $slot_2,
    branch => $uid_2,
    user   => $uid_2,
);
$result = LetsMT::WebService::copy( $resource, $uid_3 );
is( $result, 1, "POST copy branch_2 to branch_3, check status" );

$resource = new LetsMT::Resource( slot => $slot_2);
$result   = LetsMT::WebService::get_letsmt( $resource, uid => $uid_3 );
$status_hash     = xml_to_hash( $result );
$expected_status = {
    type      => 'ok',
    code      => 0,
    operation => 'GET',
    location  => "/letsmt/$slot_2",
};

is_deeply( $status_hash, $expected_status,
    "GET letsmt, list slot_2/uid_3 copied in previous step, check status"
);

$dom = xml_to_dom( $result );
is( $dom->findnodes(
              '//list[@path="/' 
            . $slot_2 . '/' 
            . $uid_3
            . '"]/entry[@kind="dir"]/name'
    )->to_literal,
    'uploads',
    '- check content: dir uploads name'
);
is( $dom->findnodes(
              '//list[@path="/' 
            . $slot_2 . '/' 
            . $uid_3
            . '"]/entry[@kind="dir"]/group'
    )->to_literal,
    $gid_2,
    '- check content: dir group name'
);
is( $dom->findnodes(
              '//list[@path="/' 
            . $slot_2 . '/' 
            . $uid_3
            . '"]/entry[@kind="dir"]/owner'
    )->to_literal,
    $uid_3,
    '- check content: dir owner name'
);


#############################################################################
# Check if import process has finished yet by trying to list .xml file 
# (language detection should find out that the text is in English)

$resource = new LetsMT::Resource(
    slot => $slot_2,
    user => $uid_2,
    path => "xml/en/$file_2.xml"
);

my $max_count = 30; #number of tries to list file
my $count     = 0;  #counter of tries to list file
my $content   = 0;

# do until file is present or max_count is reached
print "waiting for import to finish";
do {
    $count++;
    $result = LetsMT::WebService::get_letsmt( $resource, uid => $uid_2 );
    #print $result->decoded_content;

    $status_hash = xml_to_hash( $result );

    $dom = xml_to_dom( $result );
    $content = $dom->findnodes(
              '//list[@path="/' 
            . $slot_2 . '/' 
            . $uid_2  . '/'
            . 'xml/en/'
            . $file_2 . '.xml'
            . '"]/entry[@kind="file"]/name'
        )->to_literal;
    print '.';
    sleep 1 if ($content ne ($file_2.'.xml')); # wait for import to finish
} until ( $content eq ($file_2.'.xml') || $count > $max_count );

print "\n";

is( $content, $file_2 . '.xml', '- check content: file name' );

#############################################################################
# Delete slot_2/uid_2 via letsmt to delete all (including meta data)

$resource = new LetsMT::Resource( slot => $slot_2 );
$result = LetsMT::WebService::del_letsmt( $resource, uid => $uid_2 );
is( $result, 1, "DELETE letsmt, delete slot_2" );

# check if meta data is gone
$resource = new LetsMT::Resource( slot => $slot_2, path => $uid_2 );
$result = LetsMT::WebService::get_meta(
    $resource,
    uid    => $uid_2,
    action =>'list_all',
);
$status_hash     = xml_to_hash( $result );
$expected_status = {
    type      => 'error',
    code      => 7,
    operation => 'GET',
    location  => "/metadata/$slot_2/$uid_2",
};

is_deeply( $status_hash, $expected_status,
    "- check content: slot_2 meta data is gone"
);


#############################################################################
# NEGATIVE TESTS
#############################################################################

# TODO: implement negative tests and complete positive ones


#############################################################################
# CLEAN UP
#############################################################################

sub cleanup
{
    # Delete branch 'uid_3' in slot_2
    my $resource = new LetsMT::Resource( slot => $slot_2, user => $uid_3 );
    is( LetsMT::WebService::del_letsmt( $resource->path_down, uid => $uid_3 ),
        1, "DELETE letsmt, delete branch 'uid_3' in slot_2"
    );

    # Delete slot_1 via storage
    $resource = new LetsMT::Resource( slot => $slot_1 );
    is( LetsMT::WebService::del( $resource->path_down, uid => $uid_1, action => 'delete_meta' ),
        1, "DELETE storage, delete slot_1"
    );

    # Delete slot_2 via storage
    $resource = new LetsMT::Resource( slot => $slot_2 );
    is( LetsMT::WebService::del( $resource->path_down, uid => $uid_2, action => 'delete_meta' ),
        1, "DELETE storage, delete slot_2"
    );

    chdir $Bin;

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