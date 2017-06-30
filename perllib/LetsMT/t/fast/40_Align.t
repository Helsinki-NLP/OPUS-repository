#!/usr/bin/perl
#-*-perl-*-

=head1 NAME

40_Align.t - test alignment facilities

=head1 DESCRIPTION

In essence, this script tests the following assertions:

=over 2

=cut


use strict;
use warnings;

use open qw(:std :locale);

use FindBin qw( $Bin );
use lib ("$Bin/../../lib", "$Bin/..");
$ENV{PATH} = "$Bin/../../bin:$ENV{PATH}";

use Scaffold;
use Test::More;
use File::Compare;
use File::Temp;

use LetsMT::WebService;
use LetsMT::Align;

# Prepare test data
my $id   = int( rand(999999999999) );
my $slot = 'slot_name_' . $id;

chdir File::Temp::tempdir(
        'test_XXXXXX',
        DIR     => '/tmp',
        CLEANUP => 1,
    ) or die "Couldn't enter temporary directory\n";


my ($uid, $gid) = Scaffold::add_user;

my $corpus = LetsMT::Resource::make( $slot, $uid );
my $result = LetsMT::WebService::put($corpus, uid => $uid, gid => $gid);

my $srcres = LetsMT::Resource::make( $slot, $uid, "xml/en/1988.xml" );
my $trgres = LetsMT::Resource::make( $slot, $uid, "xml/sv/1988.xml" );

$result = LetsMT::WebService::put_file($srcres, "$Bin/data/opus/RF/raw/en/1988.xml");
is( $result, 1, "upload src");
$result = LetsMT::WebService::put_file($trgres, "$Bin/data/opus/RF/raw/sv/1988.xml");
is( $result, 1, "upload trg");


=item *

you CAN align resources. (Align::align_resources)

=cut

my $aligner = new LetsMT::Align();
my $algres  = $aligner->align_resources($srcres,$trgres);
is( $algres->path, "xml/en-sv/1988.xml", "ALIGN sentence alignment done!");


=item *

you CAN download the sentence-alignment file... (get_resource)

=cut

$result = LetsMT::WebService::get_resource( $algres, uid => $uid );
is( $result, 1, "DOWNLOAD sentence-alignment file" );


=item *

... and the file content is correct.

=cut

is( compare( $algres->local_path, "$Bin/data/align/en-sv/1988.xml" ),
    0, "sentence alignment file is correct" );


=item *

you CAN get automatic alignment by importing suitably named pairs of files.

=cut

$srcres = LetsMT::Resource::make( $slot, $uid, "uploads/txt/en/1988b.txt" );
$trgres = LetsMT::Resource::make( $slot, $uid, "uploads/txt/sv/1988b.txt" );

$result = LetsMT::WebService::put_file($srcres, "$Bin/data/txt/en/1988.utf8.txt");
is( $result, 1, "upload English text file" );
$result = LetsMT::WebService::put_file($trgres, "$Bin/data/txt/sv/1988.utf8.txt");
is( $result, 1, "upload Swedish text file" );

my $importer = new LetsMT::Import();
$result = $importer->import_resource( $srcres );
is( $result, 1, "IMPORT $srcres" );
$result = $importer->import_resource( $trgres );
is( $result, 1, "IMPORT $trgres" );

$algres = LetsMT::Resource::make( $slot, $uid, "xml/en-sv/1988b.xml" );
my $response = LetsMT::WebService::get( $algres, uid => $uid );

$result = LetsMT::WebService::get_resource( $algres, uid => $uid );
is( $result, 1, "DOWNLOAD sentence alignment file" );
is( compare( $algres->local_path, "$Bin/data/align/en-sv/1988b.xml" ),
    0, "sentence alignment file is correct" );

# TODO: test alignment with letsmt_align script .....


#############################################################################
# CLEAN UP
#############################################################################

sub cleanup
{
    my $resource = new LetsMT::Resource( slot => $slot );
    $result = LetsMT::WebService::del( $resource->path_down, uid => $uid );
    is( $result, 1, "DELETE slot, Clean up - remove slot" );

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