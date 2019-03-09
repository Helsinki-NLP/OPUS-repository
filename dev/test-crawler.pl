#!/usr/bin/perl


use lib "$ENV{HOME}/LetsMT-repository/perllib/LetsMT/lib";
use LetsMT::Repository::JobManager;


LetsMT::Repository::JobManager::run_crawler(
    ['corpus100','user','uploads','crawl3'],
    { # url => 'https://www.ling.helsinki.fi',
      url => 'http://www.helsinki.fi/~tiedeman/teach/ResearchSeminar/index.html',
      action => 'import',
      uid => 'user' } );

print '';
