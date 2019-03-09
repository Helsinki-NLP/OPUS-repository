#!/usr/bin/perl


use lib "$ENV{HOME}/LetsMT-repository/perllib/LetsMT/lib";

use LetsMT::DataProcessing::UDPipe;


my $udpipe = new LetsMT::DataProcessing::UDPipe;
$udpipe->load_model('en');

$udpipe->parse_xml_file('test.xml','parsed.xml');
print '';



