#!/usr/bin/perl
#-*-perl-*-

=head1 NAME

25_Repository_API_Access.t - test I<Access> API

=head1 DESCRIPTION

This script tests the following assertions:

Calling the I<Access> API via the C<WebService> module, ...

=over 2

=cut


use strict;
use warnings;

use sigtrap handler => \&cleanup, 'normal-signals';

use open qw(:std :locale);

use FindBin qw($Bin);
use lib ("$Bin/../../lib", "$Bin/..");

use Scaffold;
use Test::More;

use LetsMT::WebService;
use LetsMT::Repository::Result;
use LetsMT::Resource;

# Prepare test data
my $id     = int( rand(999999999999) );
my $slot_1   = 'slot_name_1_' . $id;

my ($uid_1, $gid_1) = Scaffold::add_user;
my ($uid_2, $gid_2) = Scaffold::add_user;

my $resource = new LetsMT::Resource( slot => $slot_1, user => $uid_1 );
LetsMT::WebService::put(
    $resource->path_down,
    uid => $uid_1,
    gid => $gid_1,
);


#############################################################################
# POSITIVE TESTS
#############################################################################

=item *

you can query the access property of an existing slot ... (get_access)

=cut

$resource  = new LetsMT::Resource( slot => $slot_1, user => $uid_1 );
my $result = LetsMT::WebService::get_access( $resource );
is_deeply( xml_to_hash( $result ), success_hash( "/access/$slot_1/$uid_1" ),
    "GET access, request access property of slot 1, check status"
);


=item *

... and the answer shows the correct group and owner name.

=cut

my $dom = xml_to_dom( $result );
ok( $dom->exists( '//list/entry[@kind="branch"][@path="'.$slot_1.'/'.$uid_1.'"][group="' . $gid_1 . '"]' ),
    '- check content: group name' );
ok( $dom->exists( '//list/entry[@kind="branch"][@path="'.$slot_1.'/'.$uid_1.'"][owner="' . $uid_1 . '"]' ),
    '- check content: owner name' );


=item *

you can change the access property of a branch to another group ... (put_access)

=cut

$resource = new LetsMT::Resource( slot => $slot_1, user => $uid_1 );
$result = LetsMT::WebService::put_access( $resource, gid => $gid_2 );
is( $result, 1, "PUT access, change access property of slot 1 to group 2" );

$resource = new LetsMT::Resource( slot => $slot_1, user => $uid_1);
$result   = LetsMT::WebService::get_access( $resource );
is_deeply(
    xml_to_hash( $result ), success_hash( "/access/$slot_1/$uid_1" ),
    "GET access, request changed access property of slot 1, check status"
);


=item *

... and a new query shows the changed property.

=cut

$dom = xml_to_dom( $result );
ok( $dom->exists( '//list/entry[@kind="branch"][@path="'.$slot_1.'/'.$uid_1.'"][group="' . $gid_2 . '"]' ),
    '- check content: group name'
);


#############################################################################
# NEGATIVE TESTS
#############################################################################

# TODO: implement negative tests and complete positive ones


#############################################################################
# CLEAN UP
#############################################################################

sub cleanup
{
    # Delete previously created slot_1
    $resource = new LetsMT::Resource( slot => $slot_1 );
    LetsMT::WebService::del( $resource->path_down, uid => $uid_1, action => 'delete_meta' );

    Scaffold::cleanup;
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