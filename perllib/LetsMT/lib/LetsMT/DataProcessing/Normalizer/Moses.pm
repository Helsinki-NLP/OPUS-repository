package LetsMT::DataProcessing::Normalizer::Moses;

=head1 NAME

LetsMT::DataProcessing::Normalizer::Moses

=head1 DESCRIPTION

A text normalizer that removes characters that should be avoided when running Moses.

=cut

use strict;
use parent 'LetsMT::DataProcessing::Normalizer';


sub normalize_no_copy {
    $_[1] =~ s/[\x00-\x1f\x7f\n]//gs;             # control characters
    $_[1] =~ s/\<(s|unk|\/s|\s*and\s*|)\>//gs;    # reserved words
    $_[1] =~ s/\[\s*and\s*\]//gs;
    $_[1] =~ s/\|/_/gs;                           # vertical bars
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