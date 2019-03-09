#!/usr/bin/perl


use lib "$ENV{HOME}/LetsMT-repository/perllib/LetsMT/lib";

use LetsMT::Resource;
use LetsMT::Export::Reader;
use LetsMT::Align;
use LetsMT::Align::Hunalign;
# use LetsMT::Align::Hunalign::BisentNew;
# use LetsMT::Align::Hunalign::Cautious;
# use LetsMT::Align::Hunalign::Bisent::Cautious;


my $srcres = LetsMT::Resource::make( $slot, $uid, "en/1988.xml" );
my $trgres = LetsMT::Resource::make( $slot, $uid, "sv/1988.xml" );
my $AlgRes = LetsMT::Resource::make('','','align.xml','.');
$AlgRes->fromDoc('en/1988.xml');
$AlgRes->toDoc('sv/1988.xml');
$AlgRes->language('en-sv');

my $aligner = new LetsMT::Align();
$aligner->align($srcres,$trgres,$AlgRes);
print '';



my $SrcRes = LetsMT::Resource::make('www.goethe.de','user','xml/de/dat.xml');
my $TrgRes = LetsMT::Resource::make('www.goethe.de','user','xml/en/dat.xml');
my $AlgRes = LetsMT::Resource::make('','','align.xml','.');
$AlgRes->fromDoc('xml/de/dat.xml');
$AlgRes->toDoc('xml/en/dat.xml');
$AlgRes->language('de-en');

my $aligner = new LetsMT::Align( verbose => 1 );
my $algres = $aligner->align_resources($SrcRes,$TrgRes);
$algres->language('de-en');
my $reader = new LetsMT::Export::Reader(undef,'xces');
$reader->open($algres);
while (my $data = $reader->read() ){
#    print join(' ',@{$$data{de}}),"\n";
 #   print join(' ',@{$$data{en}}),"\n------------------------------\n";
}


my $aligner = new LetsMT::Align::Hunalign( verbose => 1 );
$AlgRes->path('hunalign.xml');
$aligner->align($SrcRes,$TrgRes,$AlgRes);

my $aligner = new LetsMT::Align::Hunalign::Cautious( verbose => 1 );
$AlgRes->path('hunalign-cautious.xml');
$aligner->align($SrcRes,$TrgRes,$AlgRes);

# my $aligner = new LetsMT::Align( method => 'bisent', verbose => 1 );
# $AlgRes->path('hunalign-bisent.xml');
# $aligner->align($SrcRes,$TrgRes,$AlgRes);

my $aligner = new LetsMT::Align::Hunalign::Bisent( verbose => 1 );
$AlgRes->path('hunalign-bisent.xml');
$aligner->align($SrcRes,$TrgRes,$AlgRes);

my $aligner = new LetsMT::Align::Hunalign::Bisent::Cautious( verbose => 1 );
$AlgRes->path('hunalign-bisent-cautious.xml');
$aligner->align($SrcRes,$TrgRes,$AlgRes);


print '';
