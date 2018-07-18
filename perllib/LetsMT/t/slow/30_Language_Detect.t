#!/usr/bin/perl
#-*-perl-*-

=head1 NAME

10_Language_Detect.t - test language-detection facilities

=head1 DESCRIPTION

This script tests the following assertions:

=over 2

=cut


use strict;
use warnings;

use FindBin qw( $Bin );
use lib ("$Bin/../../lib", "$Bin/..");
$ENV{PATH} = "$Bin/../../bin:$ENV{PATH}";

use open qw(:std :locale);

use Scaffold;
use Test::More;
use File::Compare;

use LetsMT::Lang::Detect   qw( :all );
use LetsMT::Lang::Encoding qw( :all );


=item *

You can convert latin1-encoded text files to utf8.

=cut

my $result = text2utf8(
    'data/txt/en/1988.iso.txt',
    'data/txt/en/1988.tmp',
    undef, 'en');
is( compare('data/txt/en/1988.utf8.txt', 'data/txt/en/1988.tmp'),
    0, "convert latin1 text to utf-8 (English)"
);
unlink('data/txt/en/1988.tmp');


=item *

You can convert Russian KOI8-R-encoded text files to utf8.

=cut

$result = text2utf8(
    'data/txt/ru/rus.koi8.txt',
    'data/txt/ru/rus.tmp',
    undef, 'ru');
is( compare('data/txt/ru/rus.utf8.txt', 'data/txt/ru/rus.tmp'),
    0, "convert KOI8-R text to utf-8 (Russian)"
);
unlink('data/txt/ru/rus.tmp');

system("cp data/txt/ru/rus.koi8.txt data/txt/ru/rus.tmp");
$result = text2utf8_inplace(
    'data/txt/ru/rus.tmp',
    undef, 'ru'
);
is( compare('data/txt/ru/rus.utf8.txt', 'data/txt/ru/rus.tmp'),
    0, "convert KOI8-R text in-place to utf-8 (Russian)"
);
unlink('data/txt/ru/rus.tmp');


=item *

You can detect various character encodings of texts
(English, Swedish, Russian, Chinese;
latin1, UTF-8, UTF16, KOI8, Big5).

=cut

$result = detect_encoding('data/txt/en/1988.iso.txt','en');
is( $result, 'iso-8859-1', "detect character encoding (English, latin1)" );

$result = detect_encoding('data/txt/en/1988.utf8.txt','sv');
is( $result, 'utf-8', "detect character encoding (Swedish, utf-8)" );

$result = detect_encoding('data/txt/en/1988.utf16le.txt','en');
is( $result, 'UTF-16LE', "detect character encoding (English, UTF16LE)" );

$result = detect_encoding('data/txt/ru/rus.utf8.txt','ru');
is( $result, 'utf-8', "detect character encoding (Russian, utf-8)" );

$result = detect_encoding('data/txt/ru/rus.koi8.txt','ru');
is( $result, 'koi8-r', "detect character encoding (Russian, koi8)" );

$result = detect_encoding('data/txt/zh/chi.utf8.txt','zh');
is( $result, 'utf-8', "detect character encoding (Chinese, utf-8)" );

$result = detect_encoding('data/txt/zh/chi.big5.txt','zh');
is( $result, 'big5-eten', "detect character encoding (Chinese, big5)" );


=item *

You can detect the language of (utf-8-encoded!) texts
(English, Swedish, Russian, Chinese, Croatian).

=cut

my @lang = detect_language('data/txt/en/1988.utf8.txt');
is_deeply( \@lang, ['en'], "detect language (English)" );

@lang = detect_language('data/txt/sv/1988.utf8.txt');
is_deeply( \@lang, ['sv'], "detect language (Swedish)" );

@lang = detect_language('data/txt/ru/rus.utf8.txt');
is_deeply( \@lang, ['ru'], "detect language (Russian)" );

@lang = detect_language('data/txt/zh/chi.utf8.txt');
is_deeply( \@lang, ['zh'], "detect language (Chinese)" );       # textcat
# is_deeply( \@lang, ['zh-TW'], "detect language (Chinese)" );

@lang = detect_language('data/txt/hr/setimes.txt');
# is_deeply( \@lang, ['hr','bs'], "detect language (Croatian)" ); # textcat
is_deeply( \@lang, ['hr'], "detect language (Croatian)" );

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
