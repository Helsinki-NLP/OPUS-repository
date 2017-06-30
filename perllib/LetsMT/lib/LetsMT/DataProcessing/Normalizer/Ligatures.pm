package LetsMT::DataProcessing::Normalizer::Ligatures;

=head1 NAME

LetsMT::DataProcessing::Normalizer::

=head1 DESCRIPTION

Convert ligatures into separate letters.

=cut

use strict;
use parent 'LetsMT::DataProcessing::Normalizer';


# NB: Only typographic ligatures!
my %LIGATURES_TO_STR = (
    'Ĳ'  => 'IJ',
    'ĳ'  => 'ij',
    'Ǆ'  => 'DŽ',
    'ǅ'  => 'Dž',
    'ǆ'  => 'dž',
    'Ǉ'  => 'LJ',
    'ǈ'  => 'Lj',
    'ǉ'  => 'lj',
    'Ǌ'  => 'NJ',
    'ǋ'  => 'Nj',
    'ǌ'  => 'nj',
    'Ǳ'  => 'DZ',
    'ǲ'  => 'Dz',
    'ǳ'  => 'dz',
    '‥' => '..',
    '…' => '...',
    '⁇' => '??',
    '⁈' => '?!',
    '⁉' => '!?',
    'ﬀ' => 'ff',
    'ﬁ' => 'fi',
    'ﬂ' => 'fl',
    'ﬃ' => 'ffi',
    'ﬄ' => 'ffl',
    'ﬅ' => 'ft',
    'ﬆ' => 'st',

    #    '' => '',
    # Add more as discovered.
    # Restart MOD_PERL to put changes into effect.
);

my $REGEX = '[' . join( '', keys %LIGATURES_TO_STR ) . ']';


sub normalize_no_copy {
    $_[1] =~ s/($REGEX)/$LIGATURES_TO_STR{$1}/sge;
}


1;

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