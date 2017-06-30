#!/usr/bin/env perl

use Test::More tests => 6;
use Test::Mojo;

use FindBin;
use lib $FindBin::Bin . '/../lib';

# Load application class
my $t = Test::Mojo->new('WebInterface');
$t->ua->max_redirects(1);

$t->get_ok('/index')
    ->status_is(200)
    ->element_exists('h1','OPUS Grenzschnitte');

$t->post_form_ok('/login' => {user => 'user1', pass => 'adsdf'})
    ->status_is(200)
    ->element_exists('li', 'Logged in as: user1');

#$t->get_ok('/')
#    ->status_is(200)
#    ->element_exists('form input[name="user"]')
#    ->element_exists('form input[name="pass"]')
#    ->element_exists('form input[type="submit"]');
#
#$t->post_form_ok('/' => {user => 'test', pass => 'test'})
#    ->status_is(200)->text_like('html body' => qr/New OPUS Web Interface Logged in as: test Welcome test/);
#
#$t->get_ok('/protected')->status_is(200)->text_like('a' => qr/Logout/);
#
#$t->get_ok('/logout')->status_is(200)
#    ->element_exists('form input[name="user"]')
#    ->element_exists('form input[name="pass"]')
#    ->element_exists('form input[type="submit"]');