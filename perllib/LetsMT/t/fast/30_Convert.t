#!/usr/bin/perl
#-*-perl-*-

=head1 NAME

30_Convert.t - test file-conversion facilities

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

my $outfile = 'CONVERT-OUTPUT.tmp';


############################################################
# positive tests
############################################################

=item *

you CAN convert PDF to XML.

=item *

you CAN convert plaintext to XML, splitting into sentences and optionally tokenizing,
even if the file contains Latvian quotation marks.

=item *

you CAN convert XML to plaintext.

=item *

you CAN detokenize an XML file.

=item *

you CAN tokenize an XML file, with either the Europarl or the Uplug method.

=cut

my %commands = (

    'CONVERT pdf to text' => [
        "letsmt_convert -i pdf -m layout -o xml -b lingua data/pdf/D2.1.pdf $outfile",
        "data/xml/D2.1.xml"
    ],

    'CONVERT text to xml (with sentence splitting & Latvian quotation marks)' => [
        "letsmt_convert -i txt -o xml -b europarl -n dos data/txt/lv/file.txt $outfile",
        "data/xml/lv/file.xml"
    ],

    'CONVERT text to xml (with sentence splitting & tokenization)' => [
        "letsmt_convert -l en -t europarl -n space,ligatures -b lingua -i text -o xml data/txt/en/1988.utf8.txt $outfile",
        "data/xml/en/1988.tok.par.xml"
    ],

    'CONVERT text to xml (with sentence splitting)' => [
        "letsmt_convert -n space,ligatures -b lingua -i text -o xml data/txt/en/1988.utf8.txt $outfile",
        "data/xml/en/1988.xml"
    ],

    'CONVERT xml to text' => [
        "letsmt_convert -i xml -o text data/xml/en/1988.xml $outfile",
        "data/txt/en/1988.sent.txt"
    ],

    'DE-TOKENIZE xml file' => [
        "letsmt_detokenize -i xml -o xml data/xml/en/1988.tok.xml $outfile",
        "data/xml/en/1988.detok.xml"
    ],

    'TOKENIZE xml file' => [
        "letsmt_tokenize -i xml -o xml data/xml/en/1988.xml $outfile",
        "data/xml/en/1988.tok.xml"
    ],

    'TOKENIZE xml file with a different tokenizer' => [
        "letsmt_tokenize -i xml -o xml -m uplug data/xml/en/1988.xml $outfile",
        "data/xml/en/1988.uplug.xml"
    ],

);

foreach my $c ( sort keys %commands ) {
    system( $commands{$c}[0] );
    is( compare( $outfile, $commands{$c}[1] ), 0, $c );
    unlink($outfile);
}


=item *

you CAN convert TMX to XCES.

=cut

system("letsmt_convert -i tmx -o xces data/tmx/small.tmx small.xml");
is( compare( 'en/small.xml'   , 'data/ces/en/small.xml'    ), 0, "CONVERT tmx to xces - source file" );
is( compare( 'sv/small.xml'   , 'data/ces/sv/small.xml'    ), 0, "- target file" );
is( compare( 'en-sv/small.xml', 'data/ces/en-sv/small.xml' ), 0, "- alignment file" );

unlink('en/small.xml');
unlink('sv/small.xml');
unlink('en-sv/small.xml');
rmdir('en');
rmdir('sv');
rmdir('en-sv');


############################################################
# negative tests
############################################################

=item *

you CANNOT tokenize an XML file if you specify the wrong language.

=cut

%commands = (
    'TOKENIZE xml file with wrong language' => [
        "letsmt_tokenize -l de -i xml -o xml data/xml/en/1988.xml $outfile",
        "data/xml/en/1988.tok.xml"
    ],
);

foreach my $c ( sort keys %commands ) {
    system( $commands{$c}[0] );
    isnt( compare( $outfile, $commands{$c}[1] ), 0, $c );
    unlink($outfile);
}

=back

=cut

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