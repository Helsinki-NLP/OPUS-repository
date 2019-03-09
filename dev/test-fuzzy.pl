#!/usr/bin/perl


use lib "$ENV{HOME}/LetsMT-repository/perllib/LetsMT/lib";

use LetsMT;
use LetsMT::Resource;
use LetsMT::Corpus;


my $corpus = LetsMT::Resource::make('corpus', 'user');
my $res = LetsMT::Resource::make('corpus', 'user', 'xml/en/27.xml');

# my $corpus = LetsMT::Resource::make('subtest', 'opus');
# my $res = LetsMT::Resource::make('subtest', 'opus', 'xml/sv/adrift.xml');


my %trans = LetsMT::Corpus::find_translations($corpus,[$res]);
print '';





