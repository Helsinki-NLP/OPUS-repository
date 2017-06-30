#!/usr/bin/perl
#-*-perl-*-

=head1 NAME

20_Encoding.t - test encoding facilities

=head1 DESCRIPTION

This script tests the following assertions:

Using C<letsmt_rest>, ...

=over 2

=cut


use strict;
use warnings;

use utf8;
use open qw(:std :locale);

use FindBin qw( $Bin );
use lib ("$Bin/../../lib", "$Bin/..");
$ENV{PATH} = "$Bin/../../bin:$ENV{PATH}";

use Scaffold;
use Test::More;
use File::Compare;
use Cwd;

use LetsMT::WebService;
#use LetsMT::Align;

my $host = $ENV{LETSMT_URL};

# Prepare test data
my $id       = int( rand(999999999999) );
my $slot     = 'slot_name' . $id;
my $sub_path = 'śübṕäß12'; #not working: | .,<>

my $tmpdir = Scaffold::tempdir;

my ($uid, $gid) = Scaffold::add_user;

# create slot
my $corpus = &LetsMT::Resource::make( $slot, $uid );
LetsMT::WebService::put(
    $corpus,
    uid => $uid,
    gid => $gid,
);


=item *

you can import a file with unicode characters in its name. (import)

=cut

my $file = 'tmx/öäå.tmx';
my $result = `letsmt_rest -u $uid -s $slot import $Bin/data/$file 2>&1`;
like( $result, qr(^Upload 'uploads/$file' ... done: mkdir add .*,submitted job with ID .*),
    "TMX-file with unicode characters using letsmt_rest"
);


=item *

you can find the file in the repository's upload folder... (show)

=cut

$result = `letsmt_rest -u $uid -s $slot -p uploads/tmx/öäå.tmx show`;
is_deeply(
    xml_to_hash( $result ),
    success_hash( "/storage/$slot/$uid/uploads/$file" ),
    "GET check status TMX-file with unicode characters"
);


=item *

and the path and the name are correctly encoded.

=cut

my $dom = xml_to_dom( $result );
ok( $dom->exists( qq(//list[\@path="/$slot/$uid/uploads/tmx/öäå.tmx"]) ),
    "- check path encoding: slot/uid/uploads/tmx/öäå.tmx"
);
ok( $dom->exists( qq(//list/entry/name["öäå.tmx"]) ),
    '- check name encoding: öäå.tmx'
);


=item *

The TMX file is processed,
where the output is written to an XML file
in a path corresponding to the content language.

=cut

my $max_count = 30; # number of tries
my $count     = 0;  # counter of tries
my $content;

my $resource = new LetsMT::Resource(
    slot => $slot,
    user => $uid,
    path => 'uploads/tmx/öäå.tmx',
);
# do until file is present or max_count is reached
print "Waiting for import to finish ";
do {
    $count++;
    $result  = LetsMT::WebService::get_meta( $resource );
    $dom     = xml_to_dom( $result );
    $content = $dom->findvalue( '//list/entry/status' );
    print( ($count % 5) ? '.' : '*' );
    sleep 1 if ($content ne ('imported')); # wait for import to finish
} until ( $content eq ('imported') || $count > $max_count );
print "\n";

$resource = new LetsMT::Resource(
    slot => $slot,
    user => $uid,
    path => 'xml/sv',
);
$result = LetsMT::WebService::get( $resource, uid => $uid );
$dom    = xml_to_dom( $result );
is( $dom->findnodes( '//list/entry/name' )->to_literal,
    'öäå.xml',
    '- check content: name of imported file'
);

=back


Likewise, communicating via cURL, ...

=over 2

=item *

you can import a file with unicode characters in its name. (PUT storage/...&action=import)

=cut

my $location = "storage/$slot/$uid/uploads/tmx/$sub_path/kažociņš.tmx";
$result = `$ENV{LETSMT_CONNECT} --form "payload=\@data/tmx/small.tmx" -X PUT "$host/$location?uid=$uid&action=import"`;
is_deeply(
    xml_to_hash( $result ), success_hash( "/$location", 'PUT' ),
    "PUT TMX-file with unicode characters using cURL"
);

=item *

you can show the file. (letsmt_rest show -p ...)

=cut

# check file is there
$result = `letsmt_rest -u $uid -s $slot -p uploads/tmx/$sub_path/kažociņš.tmx show`;
is_deeply(
    xml_to_hash( $result ), success_hash( "/$location" ),
    "GET list TMX-file with unicode characters"
);


=item *

you can download the copy of the file saved in the repository,
and its content is as in the original. (PUT storage/...&action=import)

=cut

##############################################################################
# fetch file from cURL upload, this gives no xml output to check for
$file = 'small_downloaded.tmx';
$result = `$ENV{LETSMT_CONNECT} -o "$tmpdir/$file" -X GET "$host/storage/$slot/$uid/uploads/tmx/$sub_path/kažociņš.tmx?uid=$uid&action=download&archive=0"`;

ok( -f "$tmpdir/$file", "- check downloaded file exists" );
is( compare( 'data/tmx/small.tmx', "$tmpdir/$file" ),
    0, "- check content: content of uploaded and downloaded file match"
);
unlink "$tmpdir/$file";


##############################################################################
# cat file from cURL import



##############################################################################
# check if file got imported via cURL import

$max_count = 30; #number of tries
$count     = 0;  #counter of tries

$resource = new LetsMT::Resource(
    slot => $slot,
    user => $uid,
    path => "uploads/tmx/$sub_path/kažociņš.tmx",
);
# do until file is present or max_count is reached
print "waiting for import to finish ";
do {
    $count++;
    $result  = LetsMT::WebService::get_meta( $resource );
    $dom     = xml_to_dom( $result );
    $content = $dom->findvalue( '//list/entry/status' );
    print( ($count % 5) ? '.' : '*' );
    sleep 1 if ($content ne ('imported')); # wait for import to finish
} until ( $content eq ('imported') || $count > $max_count );
print "\n";


=item *

the imported file is named correctly.

=cut

$resource = new LetsMT::Resource(
    slot => $slot,
    user => $uid,
    path => "xml/en/$sub_path",
);
$result = LetsMT::WebService::get( $resource, uid => $uid );
$dom = xml_to_dom( $result );
is( $dom->findnodes( '//list/entry/name["kažociņš.xml"]' )->to_literal,
    'kažociņš.xml',
    '- check content: name of imported file'
);


##############################################################################
# set metadata values containing unicode characters

my $value = 'ö äå<ž>ņš|\.:@/[}#$%^-_';
$resource = new LetsMT::Resource( slot => $slot, user => $uid );
my %meta = ( 'utf8' => $value );
$result = LetsMT::WebService::put_meta( $resource, %meta );

=item *

You can set metadata with a utf8 value. (WebService: put_meta)

=cut

is( $result,
    1,
    "PUT meta data containing utf-8, add new meta data to slot/uid"
);

$result = LetsMT::WebService::get_meta($resource, action=>'list_all');
$dom = xml_to_dom( $result );
ok( $dom->exists( qq(//list[\@path=""]/entry[\@path="$slot/$uid"]/utf8["$value"]) ),
    '- check content: slot/uid has new meta data'
);


##############################################################################
## CLEAN UP
##############################################################################

sub cleanup
{
    ## Delete slot
    $resource = new LetsMT::Resource( slot => $slot );
    $result = LetsMT::WebService::del(
        $resource->path_down,
        uid    => $uid,
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