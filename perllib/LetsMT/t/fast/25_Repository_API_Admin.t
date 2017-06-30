#!/usr/bin/perl
#-*-perl-*-

=head1 NAME

25_Repository_API_Admin.t - test I<Admin> API

=head1 DESCRIPTION

This script tests the following assertions:

Calling the I<Admin> API via the C<WebService> module, ...

=over 2

=cut


use strict;
use warnings;

use open qw(:std :locale);

use FindBin qw($Bin);
use lib ("$Bin/../../lib", "$Bin/..");

use Scaffold;
use Test::More;

use LetsMT::WebService;
#use LetsMT::Repository::Result;
use LetsMT::Resource;

my $id     = int( rand(999999999999) );
my $slot_1 = 'slot_name_1_' . $id;

$id        = int( rand(999999999999) );
my $slot_2 = 'slot_name_2_' . $id;

my ($uid_1, $gid_1) = Scaffold::add_user;
my ($uid_2, $gid_2) = Scaffold::add_user;

my $resource = new LetsMT::Resource( slot => $slot_1, user => $uid_1 );
LetsMT::WebService::put(
    $resource->path_down,
    uid => $uid_1,
    gid => $gid_1
);

$resource = new LetsMT::Resource( slot => $slot_2, user => $uid_2 );
LetsMT::WebService::put(
    $resource->path_down,
    uid => $uid_2,
    gid => $gid_2
);


#############################################################################
# POSITIVE TESTS
#############################################################################

=item *

you can query the svn path for a branch. (get_admin)

=cut

$resource  = new LetsMT::Resource(
    slot => $slot_1,
    path => $uid_1,
    user => $uid_1,
);
my $result = LetsMT::WebService::get_admin(
    $resource,
    type => 'svnpath'
);
is_deeply( xml_to_hash( $result ), success_hash ( "/admin/$slot_1/$uid_1" ),
    "GET admin, request svn path for slot_1/uid_1, check status"
);


my $dom = xml_to_dom( $result );
is( $dom->findnodes( qq(//list["file:///$slot_1/$uid_1"]/entry[\@kind="svn path"]) )->to_literal,
    qq(file://$ENV{LETSMTDISKROOT}/$slot_1/$uid_1),
    '- check content: svn path'
);


=item *

you can list the svn paths for all the slots. (get_admin)

=cut

$resource = new LetsMT::Resource( );
$result   = LetsMT::WebService::get_admin(
    $resource,
    type => 'svnpath',
    uid  => $uid_1,
);
is_deeply( xml_to_hash( $result ), success_hash( "/admin/" ),
    "GET admin, request svn path for all slots"
);

$dom = xml_to_dom( $result );
ok( $dom->exists( '//list["file:////"]/entry[@kind="svn path"]["file://' . $ENV{LETSMTDISKROOT} . '/' . $slot_1 . '/"]' ),
    '- check content: svn path for slot_1 exists'
);
ok( $dom->exists( '//list["file:////"]/entry[@kind="svn path"]["file://' . $ENV{LETSMTDISKROOT} . '/' . $slot_2 . '/"]' ),
    '- check content: svn path for slot_2 exists'
);


#############################################################################
# NEGATIVE TESTS
#############################################################################




#############################################################################
# CLEAN UP
#############################################################################

sub cleanup
{
    # Delete previously created slot_1
    $resource = new LetsMT::Resource( slot => $slot_1 );
    LetsMT::WebService::del( $resource->path_down, uid => $uid_1, action => 'delete_meta' );

    # Delete previously created slot_2
    $resource = new LetsMT::Resource( slot => $slot_2 );
    LetsMT::WebService::del( $resource->path_down, uid => $uid_2, action => 'delete_meta' );

    &Scaffold::cleanup;
}

=back

=cut


&cleanup;

done_testing;


#
# This file is part of LetsMT! Resource Repository.
#
# LetsMT! Resource Repository is free software: you can redistribute it
# and/or modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# LetsMT! Resource Repository is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with LetsMT! Resource Repository.  If not, see
# <http://www.gnu.org/licenses/>.
#