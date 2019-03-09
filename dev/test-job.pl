#!/usr/bin/perl


use lib "$ENV{HOME}/LetsMT-repository/perllib/LetsMT/lib";

use LetsMT::Resource;
use LetsMT::Repository::JobManager;

use LetsMT::Repository::API::Job;

my $jobapi = new LetsMT::Repository::API;
my $jobapi = new LetsMT::Repository::API::Job;
$jobapi->{args}->{run} = 'reimport';
$jobapi->{args}->{path_elements} = [ 'www.hel.fi', 'opus',
				     'uploads','craw-all.tar.gz' ];
$jobapi->{args}->{uid} = 'opus';
$jobapi->put();


LetsMT::Repository::JobManager::run('reimport',
				    [ 'www.hel.fi', 'opus',
				      'uploads','craw-all.tar.gz' ],
				    { uid => 'opus'} );

print '';
