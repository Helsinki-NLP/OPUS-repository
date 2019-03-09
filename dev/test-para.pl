#!/usr/bin/perl


use lib "$ENV{HOME}/LetsMT-repository/perllib/LetsMT/lib";

use LetsMT::Resource;
use LetsMT::Export::Reader::Corpus;
use LetsMT::Export::Writer::TMX;

my $res = LetsMT::Resource::make('subtest2018','opus','xml/fi-sv');
my $reader = new LetsMT::Export::Reader::Corpus;
my $writer1 = new LetsMT::Export::Writer::TMX;
my $writer2 = new LetsMT::Export::Writer::TMX::Unique;

my $tmx1 = LetsMT::Resource::make('','','file1.tmx');
my $tmx2 = LetsMT::Resource::make('','','file2.tmx');

$writer1->open($tmx1) || die "cannot write to file1";
$writer2->open($tmx2) || die "cannot write to file2";

if ($reader->open($res)){
    my $data = {};
    while ( $data = $reader->read ) {
	$writer1->write($data);
	$writer2->write($data);
    }
    $writer1->close;
    $writer2->close;
}
