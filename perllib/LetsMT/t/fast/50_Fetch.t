#!/usr/bin/perl
#-*-perl-*-

=head1 NAME

50_Fetch.t - test file-fetching facilities

=head1 DESCRIPTION

This script tests the following assertions:

=over 2

=cut


use strict;
use warnings;

use open qw(:std :locale);

use FindBin qw( $Bin );
use lib ("$Bin/../../lib", "$Bin/..");
$ENV{PATH} = "$Bin/../../bin:$ENV{PATH}";

use Scaffold;
use Test::More;
use File::Compare;

use LetsMT::WebService;

my $id = int( rand(999999999999) );

my ($uid, $gid) = Scaffold::add_user;

=pod

After reading OPUS data via C<letsmt_import -o>, ...

=cut

system("mkdir RF_$id");
system("tar -xzf data/opus/RF.tar.gz -C RF_$id");
system("letsmt_import -o -u $uid -d RF_$id RF");
system("rm -fr RF_$id");


=over 2

=item *

everything is imported.
(Very selective test so far...)

=cut

my $response = `letsmt_rest -u $uid -s RF -d xml/en-sv show`;
my $dom      = xml_to_dom( $response );
my @nodes = $dom->findnodes('//entry/name');
is( $#nodes, 1, "UPLOAD opus test, 2 alignment files en-sv" );


=item *

you CAN fetch the files from the corpus via C<letsmt_fetch>.

=cut

system("letsmt_fetch -u $uid data/smt/test.smt");
for my $f ('mono', 'para.sv', 'para.en', 'tune.sv', 'tune.en', 'eval.sv', 'eval.en') {
    ok( -s $f, "Fetched file '$f' has non-zero size" );
    unlink($f);
}


#############################################################################
# CLEAN UP
#############################################################################

sub cleanup
{

=item *

you CAN delete the slot from the repository.

=cut

    my $resource = new LetsMT::Resource( slot => "RF", path => "$uid");
    my $result = LetsMT::WebService::del( $resource, uid => $uid );
    is( $result, 1, "DELETE slot, Clean up - remove slot" );

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