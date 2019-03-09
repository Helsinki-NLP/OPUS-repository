#!/usr/bin/perl


use lib "$ENV{HOME}/OPUS-repository/perllib/LetsMT/lib";

use LetsMT::Resource;
use LetsMT::Align::Documents;




my $corpus = LetsMT::Resource::make( 'www.helsinki.fi', 'opus' );
LetsMT::Align::Documents::resources_with_language_links( $corpus );



my $upload = LetsMT::Resource::make( 'www.helsinki.fi', 'opus', 'uploads/crawl_aa.tar.gz' );

LetsMT::Align::Documents::find_language_links( $upload, 'helsinki' );


my $corpus = LetsMT::Resource::make( 'web.vnk.fi', 'opus' );
my $upload = LetsMT::Resource::make( 'web.vnk.fi', 'opus', 'uploads/crawl_aa.tar.gz' );

LetsMT::Align::Documents::find_language_links( $upload );



$par = {};
$count = resources_with_language_links($corpus,$par);
print '';
