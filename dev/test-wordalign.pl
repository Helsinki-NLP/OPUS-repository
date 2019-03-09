#!/usr/bin/perl


use lib "$ENV{HOME}/LetsMT-repository/perllib/LetsMT/lib";

use LetsMT::Resource;
use LetsMT::Align::Words::Eflomal;


my $algres = LetsMT::Resource::make('opustest2','user','xml/en-sv/5.html.xml');
my $aligner = new LetsMT::Align::Words::Eflomal;

$aligner->wordalign($algres);
print '';



