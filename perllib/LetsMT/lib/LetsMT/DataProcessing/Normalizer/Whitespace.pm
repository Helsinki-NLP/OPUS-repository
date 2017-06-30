package LetsMT::DataProcessing::Normalizer::Whitespace;

=head1 NAME

LetsMT::DataProcessing::Normalizer::Whitespace

=head1 DESCRIPTION

Remove duplicate, leading, and trailing whitespaces.

=cut

use strict;
use parent 'LetsMT::DataProcessing::Normalizer';


sub normalize_no_copy {
    $_[1] =~ s/[\s\n]+/ /gs;    # Normalize whitespaces.
    $_[1] =~ s/^\s*//;          # Remove leading whitespaces.
    $_[1] =~ s/\s*$//;          # Remove trailing whitespaces.
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