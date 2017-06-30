#!/usr/bin/perl
#-*-perl-*-

=head1 NAME

22_Repository_API_MetaData.t - test I<MetaData> API

=head1 DESCRIPTION

This script tests the following assertions:

Calling the I<MetaData> API via the C<WebService> module, ...

=over 2

=cut


use strict;
use warnings;

use utf8;
use open qw(:std :locale);

use FindBin qw($Bin);
use lib ("$Bin/../../lib", "$Bin/..");

use Scaffold;
use Test::More;

use LetsMT::WebService;
use LetsMT::Repository::Result;
use LetsMT::Resource;

# Prepare test data
my $id     = int( rand(999999999999) );
my $slot_1 = 'slot_name_1_' . $id;

$id = int( rand(999999999999) );
my $slot_2 = 'slot_name_2_' . $id;
my $file_2 = 'test_file_2_' . $id . '.txt';

my $rand_1 = 'rand_1_' . int( rand(999999999999) );
my $rand_2 = 'rand_2_' . int( rand(999999999999) );
my $rand_3 = 'rand_3_' . int( rand(999999999999) );
my $rand_4 = 'rand_4_' . int( rand(999999999999) );

# Create slot_1 with 'uid_1'
# Create slot_2 with 'uid_2'

my ($uid_1, $gid_1) = Scaffold::add_user;
my ($uid_2, $gid_2) = Scaffold::add_user;

my $resource = new LetsMT::Resource( slot => $slot_1, user => $uid_1 );
LetsMT::WebService::put(
    $resource->path_down,
    uid => $uid_1,
    gid => $gid_1,
);

$resource = new LetsMT::Resource( slot => $slot_2, user => $uid_2 );
LetsMT::WebService::put(
    $resource->path_down,
    uid => $uid_2,
    gid => $gid_2,
);


#############################################################################
# POSITIVE TESTS
#############################################################################

=item *

you can query the metadata of a slot ... (get_meta)

=cut

$resource  = new LetsMT::Resource( slot => $slot_1 );
my $result = LetsMT::WebService::get_meta(
    $resource,
    uid => $uid_1,
);
my $expected_status = {
    type      => 'ok',
    code      => 0,
    operation => 'GET',
    location  => "/metadata/$slot_1",
};
is_deeply( xml_to_hash( $result ), $expected_status,
    "GET metadata, list metadata of slot_1, check status"
);


=item *

... and information concerning I<path>, I<creator> and I<resource-type>
is available.

=cut

my $dom = xml_to_dom( $result );
ok( $dom->exists( qq(//list[\@path=""]/entry[\@path="$slot_1"]) ),
    '- check content: slot_1 path metadata exists'
);
ok( $dom->exists( qq(//list[\@path=""]/entry/creator["$uid_1"]) ),
    '- check content: slot_1 creator metadata exists'
);
ok( $dom->exists( qq(//list[\@path=""]/entry/resource-type["slot"]) ),
    '- check content: slot_1 resource-type metadata exists'
);


=item *

you can also query the metadata of a branch. (get_meta)

=cut

$resource = new LetsMT::Resource( slot => $slot_1, path => $uid_1 );
$result   = LetsMT::WebService::get_meta(
    $resource,
    uid    => $uid_1,
);
is_deeply( xml_to_hash( $result ), success_hash( "/metadata/$slot_1/$uid_1" ),
    "GET metadata by id, list metadata of slot_1/uid_1, check status"
);


$dom = xml_to_dom( $result );
ok( $dom->exists( '//list[@path=""]/entry[@path="' . $slot_1 . '/' . $uid_1 . '"]' ),
    '- check content: slot_1/uid_1 path metadata exists'
);
ok( $dom->exists( '//list[@path=""]/entry/uid["' . $uid_1 . '"]' ),
    '- check content: slot_1/uid_1 uid metadata exists'
);
ok( $dom->exists('//list[@path=""]/entry/resource-type["branch"]'),
    '- check content: slot_1/uid_1 resource-type metadata exists'
);


=item *

you can add new metadata. (put_meta)

=cut

$resource = new LetsMT::Resource( slot => $slot_1, user => $uid_1 );
my %meta = ( $rand_1 => $rand_2 );
$result = LetsMT::WebService::put_meta( $resource, %meta );
is( $result, 1, "PUT metadata, add new metadata to slot_1/uid_1" );

$result = LetsMT::WebService::get_meta( $resource );
$dom    = xml_to_dom( $result );
ok( $dom->exists( qq(//list[\@path=""]/entry[\@path="$slot_1/$uid_1"]/${rand_1}\["$rand_2"]) ),
    '- check content: slot_1/uid_1 has new metadata'
);


=item *

you can extend existing metadata. (put_meta)

=cut

%meta = ( $rand_1 => $rand_3 );
$result = LetsMT::WebService::put_meta( $resource, %meta );
is( $result, 1,
    "PUT metadata, add metadata to existing entry in slot_1/uid_1"
);

$result = LetsMT::WebService::get_meta( $resource );
$dom    = xml_to_dom( $result );
ok( $dom->exists( qq(//list[\@path=""]/entry[\@path="$slot_1/$uid_1"]/${rand_1}["$rand_1,$rand_3"]) ),
    '- check content: slot_1/uid_1 has new extended metadata'
);


=item *

you can overwrite metadata. (put_meta)

=cut

%meta = ( $rand_1 => $rand_4 );
$result = LetsMT::WebService::post_meta( $resource, %meta );
is( $result, 1, "POST metadata, overwrite metadata in slot_1/uid_1" );

$result = LetsMT::WebService::get_meta( $resource );
$dom    = xml_to_dom( $result );
ok( $dom->exists( qq(//list[\@path=""]/entry[\@path="$slot_1/$uid_1"]/${rand_1}["$rand_4"]) ),
    '- check content: slot_1/uid_1 metadata got overwritten'
);


=item *

you can search the metadata for a specific key=value pair. (search_meta)

=cut

$result = LetsMT::WebService::search_meta(
    uid     => $uid_1,
    $rand_1 => $rand_4,
    action  =>'list_all'
);
$dom = xml_to_dom( $result );
is( $dom->findnodes( qq(//list[\@path=""]/entry[\@path="$slot_1/$uid_1"]/$rand_1) )->to_literal,
    $rand_4,
    'GET search metadata - check content: slot_1/uid_1 metadata key and value are found'
);


=item *

you can search the metadata for a key=value pair
using the special search-modifier prefix I<STARTS_WITH_>. (search_meta)

=cut

$result = LetsMT::WebService::search_meta(
    uid    => $uid_1,
    'STARTS_WITH_' . $rand_1 => substr( $rand_4, 0, 5 ),
    action =>'list_all'
);
$dom = xml_to_dom( $result );
is( $dom->findnodes( qq(//list[\@path=""]/entry[\@path="$slot_1/$uid_1"]/$rand_1) )->to_literal,
    $rand_4,
    'GET search metadata - check content: slot_1/uid_1 metadata are found with STARTS_WITH'
);


# Add second value to existing key again
$resource = new LetsMT::Resource( slot => $slot_1, user => $uid_1 );
%meta = ( $rand_1 => $rand_2 );
$result = LetsMT::WebService::put_meta( $resource, %meta );
is( $result, 1,
    "PUT metadata, add metadata to exsisting entry in slot_1/uid_1"
);


=item *

you can search the metadata for a key=value(s) pair
using the modifier prefix I<ONE_OF_>. (search_meta)

=cut

# Search for metadata for specific key=value pair with special search option
$result = LetsMT::WebService::search_meta(
    uid => $uid_1,
    'ONE_OF_' . $rand_1 => $rand_2,
    action =>'list_all'
);
$dom = xml_to_dom( $result );

my $one_of_result = $dom->findnodes( qq(//list[\@path=""]/entry[\@path="$slot_1/$uid_1"]/$rand_1) )->to_literal;
my @one_of_array = sort split( ',', $one_of_result );
is_deeply(
    \@one_of_array,
    [ $rand_2, $rand_4 ],
    'GET search metadata - check content: slot_1/uid_1 metadata are found with ONE_OF'
);


=item *

you can delete a single value from a metadata entry. (del_meta)

=cut

%meta = ( $rand_1 => $rand_4 );
$result = LetsMT::WebService::del_meta( $resource, %meta );
is( $result, 1,
    "DELETE metadata, delete one value from metadata key in slot_1/uid_1"
);

$result = LetsMT::WebService::get_meta( $resource, uid => $uid_1 );
#print $result->decoded_content;
$dom = xml_to_dom( $result );
is( $dom->findnodes( qq(//list[\@path=""]/entry[\@path="$slot_1/$uid_1"]/$rand_1) )->to_literal,
    $rand_2,
    '- check content: slot_1/uid_1 metadata value only the deleted one is gone'
);


=item *

you can delete a complete metadata entry. (del_meta)

=cut

%meta = ( $rand_1 => '*');
$result = LetsMT::WebService::del_meta( $resource, %meta );
is( $result, 1, "DELETE metadata, delete metadata key in slot_1/uid_1" );

$result = LetsMT::WebService::get_meta( $resource, uid => $uid_1 );
$dom    = xml_to_dom( $result );
ok( ! $dom->exists( qq(//list[\@path=""]/entry[\@path="$slot_1/$uid_1"]/$rand_1) ),
    '- check content: slot_1/uid_1 metadata key that got deleted is gone'
);


=item *

you can delete all the metadata from a branch. (del_meta)

=cut

$result = LetsMT::WebService::del_meta($resource);
is( $result, 1, "DELETE metadata, delete all metadata of slot_1/uid_1" );

$result = LetsMT::WebService::get_meta($resource, uid => $uid_1, action=>'list_all');
$dom    = xml_to_dom( $result );
ok( ! $dom->exists( '//list[@path=""]/entry[@path="' . $slot_1 . '/' . $uid_1 . '"]/*' ),
    '- check content: slot_1/uid_1 all metadata is gone'
);


=item *

you can set metadata values containing unicode characters.

=cut

my $value = 'ö äå<ž>ņš|\.:@/[}#$%^-_';
$result = LetsMT::WebService::put_meta(
    $resource,
    'utf8' => $value
);
is( $result, 1, "PUT metadata containing utf-8, add new metadata to slot/uid" );

$result = LetsMT::WebService::get_meta( $resource );
$dom = xml_to_dom( $result );
ok( $dom->exists( qq(//list[\@path=""]/entry[\@path="$slot_1/$uid_1"]/utf8["$value"]) ),
    '- check content: slot/uid has new metadata'
);


=item *

when deleting a slot or branch,
you can have the corresponding metadata deleted at the same time.
(del, action => delete_meta)

=cut

$resource = new LetsMT::Resource( slot => $slot_2 );
$result = LetsMT::WebService::del(
    $resource->path_down,
    uid    => $uid_2,
    action => 'delete_meta'
);
is( $result, 1, "DELETE storage, delete slot_2" );

# Get metadata from slot_2/uid_2 by id
$resource = new LetsMT::Resource(
    slot => $slot_2,
    user => $uid_2,
);
$result   = LetsMT::WebService::get_meta(
    $resource,
    action => 'list_all'
);
$expected_status = {
    type      => 'error',
    code      => 7,
    operation => 'GET',
    location  => "/metadata/$slot_2/$uid_2",
};
is_deeply( xml_to_hash( $result ), $expected_status,
    "GET metadata by id, try to list metadata of slot_2/uid_2, check status"
);

$dom = xml_to_dom( $result );
ok( ! $dom->exists( '//list[@path=""]/entry[@path="' . $slot_2 . '/' . $uid_2 . '"]/*' ),
    '- check content: slot_2/uid_2 all metadata is gone'
);


#############################################################################
# NEGATIVE TESTS
#############################################################################

#############################################################################
# Search for metadata that does not exist

#############################################################################
# Delete metadata of slot_1/uid_1 that does not exist


#############################################################################
# CLEAN UP
#############################################################################

sub cleanup
{
    # Delete slots
    my $resource = new LetsMT::Resource( slot => $slot_1 );
    LetsMT::WebService::del(
        $resource->path_down,
        uid    => $uid_1,
        action => 'delete_meta',
    );

    # for good measure / in case of abort
    $resource = new LetsMT::Resource( slot => $slot_2 );
    LetsMT::WebService::del(
        $resource->path_down,
        uid    => $uid_2,
        action => 'delete_meta'
    );

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