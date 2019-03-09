#!/usr/bin/perl


use lib "$ENV{HOME}/LetsMT-repository/perllib/LetsMT/lib";

use LetsMT::Import;
use LetsMT::Resource;
use LetsMT::Import::PDF;

my $pdfres = LetsMT::Resource::make( '', '', "D2.1.pdf" );
my $xmlres = LetsMT::Resource::make( '', '', "D2.1.xml" );


LetsMT::Import::PDF::convert_pdf2xml_cmd($pdfres,$xmlres);
print '';
