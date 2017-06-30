#!/usr/bin/perl
#-*-perl-*-

=head1 NAME

50_Repository_Import.t - test importing facilities

=head1 DESCRIPTION

This script tests the following assertions:

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
use File::Slurp;
use File::Basename;

use LetsMT::WebService;
use LetsMT::Repository::Result;
use LetsMT::Resource;
use LetsMT::Import;

#LetsMT::WebService::verbose();

# Prepare test data
my $id   = int( rand(999999999999) );
my $slot = 'slot_name_' . $id;


#############################################################################
# POSITIVE TESTS
#############################################################################
# Create slot with uid

my ($uid, $gid) = Scaffold::add_user;

my $resource = new LetsMT::Resource(
    slot => $slot,
    user => $uid
);
my $result = LetsMT::WebService::put(
    $resource->path_down,
    uid => $uid,
    gid => $gid,
);

is( $result, 1, "PUT storage, create slot with user uid" );

# test upload files and their format
my %files = (
    'data/tmx/small.tmx'              => 'tmx',
    'data/tmx/small.tmx.gz'           => 'tmx',
    'data/tmx/LEGO_EN_LT.tmx'         => 'tmx',     # slightly corrupt xml
    'data/tmx/Bendra_TILDE_EN-LT.tmx' => 'tmx',     # slightly corrupt xml
    'data/moses/small.tar'            => 'moses',
    'data/moses/Balanced Evaluation Set.tar.gz' => 'moses',
    'data/moses/Balanced Tuning Set.zip'        => 'moses',
    'data/pdf/D2.1.pdf'               => 'pdf',
    'data/pdf/blaa1_importing.pdf'    => 'pdf',    # pdf with a lot of
    'data/pdf/blaa_adv_importing.pdf' => 'pdf',    # different UTF8 characters
    'data/txt/en/1988.iso.txt.gz'     => 'txt',    # gzipped txt
    'data/txt/en/1988.utf8.txt'       => 'txt',
    'data/txt/sv/1988.utf8.txt'       => 'txt',
    'data/txt/en/1988.utf16le.txt'    => 'txt',    # utf16le encoded text
    'data/doc/de/test.doc'            => 'doc',    # created with OpenOffice
    'data/doc/en/test.docx'           => 'doc',    # created with AbiWord
    'data/doc/Alices Adventures in Wonderland.doc'  => 'doc',  # strange names
    "data/doc/Alice's Adventures in Wonderland.doc" => 'doc',  # with spaces
    'data/doc/Alice"s Adventures in Wonderland.doc' => 'doc',  # and quotes
    'data/xliff/polish/workbench_tasks.xliff'       => 'xliff',
    'data/xliff/xliff.tar'                          => 'xliff',
    'data/xliff/xliff.tgz'                          => 'xliff',
    'data/xliff/xliff.zip'                          => 'xliff',
    'data/language_code_file_names.zip'             => 'txt',   #files names with language codes
);

my $parser = new XML::LibXML;

foreach my $f ( sort keys %files ) {
    my $path = 'uploads/' . $files{$f} . '/' . basename($f);
    my $resource = LetsMT::Resource::make( $slot, $uid, $path );
    &lowlevel_upload( $resource, $f, $files{$f} );

    # run importer ....
    print "import '$f' ...\n";

    my $importer = new LetsMT::Import();
    $result      = $importer->import_resource($resource);
    is( $result, 1, "IMPORT $f, format = $files{$f}" );

    # check if metadata status is set to "imported"
    $result = LetsMT::WebService::get_meta($resource);
    my $dom = xml_to_dom( $result );
    is( $dom->findnodes('//entry/status')->to_literal,
        'imported', "IMPORT resource $f is imported"
    );

    # check if new resources are created
    isnt( scalar @{ $importer->{new_resources} },
        0, "IMPORT of ($f) generated new resources"
    );

    # check if we can find them
    foreach my $res ( @{ $importer->{new_resources} } ) {
        $result = LetsMT::WebService::get_meta($res);
        $dom = xml_to_dom( $result );
        isnt( $dom->findnodes('//size')->to_literal,
            0, "Non-zero size after import ($res)"
        );
    }
}

# Check if file with language codes in file name has proper languages set 
my $lang_resource = LetsMT::Resource::make( $slot, $uid, 'xml/lv/language_code_file_names/lv-en_foobar.lv.xml' );
$result = LetsMT::WebService::get_meta($lang_resource);
my $dom = xml_to_dom( $result );
is( $dom->findnodes('//language')->to_literal,
    'lv', "language code in file name ignored properly (lv)"
);

$lang_resource = LetsMT::Resource::make( $slot, $uid, 'xml/en/language_code_file_names/lv-en_foobar.en.xml' );
$result = LetsMT::WebService::get_meta($lang_resource);
#print $result->decoded_content;
$dom = xml_to_dom( $result );
is( $dom->findnodes('//language')->to_literal,
    'en', "language code in file name ignored properly (en)"
);


#############################################################################
# NEGATIVE TESTS
#############################################################################

# test upload of corrupt files
%files = (    
    'data/tmx/corrupt.tmx'                           => 'tmx',
    "data/doc/Alice's Adventures in Wonderland.docx" => 'doc',
);

foreach my $f ( keys %files ) {
    my $resource = LetsMT::Resource::make( $slot, $uid, "uploads/$files{$f}/$f" );
    &lowlevel_upload( $resource, $f, $files{$f} );

    # run importer ....
    my $importer = new LetsMT::Import();
    my $result   = $importer->import_resource($resource);
    is( $result, 0, "No IMPORT $f, format = $files{$f}" );

    # check if metadata status is NOT set to "imported"
    $result = LetsMT::WebService::get_meta($resource);
    my $dom = xml_to_dom( $result );
    isnt( $dom->findnodes('//entry/status')->to_literal,
        'imported', "No IMPORT corrupt resource $f is not imported"
    );

    # check if new resources are created
    is( scalar @{ $importer->{new_resources} },
        0, "No IMPORT of ($f) generated new resources"
    );
}

#############################################################################
# CLEAN UP
#############################################################################

sub cleanup
{
    # Delete slots
    my $resource = new LetsMT::Resource( slot => $slot );
    my $result = LetsMT::WebService::del( $resource->path_down, uid => $uid );
    is( $result, 1, "DELETE slot, Clean up - remove slot" );

    Scaffold::cleanup;
}

=back

=cut


&cleanup;

done_testing;


#############################################################################

sub lowlevel_upload {
    # upload a test file (use lowlevel to avoid automatic import)
    my ( $resource, $file, $format ) = @_;

#    if ($file eq 'data/txt/sv/1988.utf8.txt'){
#        print '';
#    }

    my $result = LetsMT::WebService::put_file( $resource, $file );
    is( $result, 1, "PUT storage, upload test file '$file' via PUT" );
}


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