#!/usr/bin/perl
#-*-perl-*-

=head1 NAME

10_letsmt_rest.t - test C<letsmt_rest> UI

=head1 DESCRIPTION

This script tests the following assertions:

Using C<letsmt_rest>, ...

=over 2

=cut


use strict;
use warnings;

use utf8;
use open qw(:std :locale);

use FindBin qw( $Bin );
use lib ("$Bin/../../lib", "$Bin/..");
$ENV{PATH} = "$Bin/../../bin:$ENV{PATH}";

use Scaffold;
use Test::More;
use File::Compare;
use Cwd;


my $host = $ENV{LETSMT_URL};

# Prepare test data
my $id       = int( rand(999999999999) );
my $slot     = 'slot_name' . $id;

my ($uid, $gid) = Scaffold::add_user;


=item *

you can import a file with unicode characters in its name. (import)

=cut

my $file = 'tmx/öäå.tmx';
my $result = `letsmt_rest -u $uid -s $slot import $Bin/data/$file 2>&1`;
like( $result, qr(^Upload 'uploads/$file' ... done),
    "TMX-file with unicode characters using letsmt_rest"
);


=item *

you can find the file in the repository's upload folder... (show)

=cut

$result = `letsmt_rest -u $uid -s $slot -p uploads/tmx/öäå.tmx show`;
is_deeply(
    xml_to_hash( $result ),
    success_hash( "/storage/$slot/$uid/uploads/$file" ),
    "GET check status TMX-file with unicode characters"
);


=item *

and the path and the name ARE correctly encoded.

=cut

my $dom = xml_to_dom( $result );
ok( $dom->exists( qq(//list[\@path="/$slot/$uid/uploads/tmx/öäå.tmx"]) ),
    "- check path encoding: slot/uid/uploads/tmx/öäå.tmx"
);
ok( $dom->exists( qq(//list/entry/name["öäå.tmx"]) ),
    '- check name encoding: öäå.tmx'
);




##############################################################################
## CLEAN UP
##############################################################################

sub cleanup
{
    Scaffold::cleanup;
}


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