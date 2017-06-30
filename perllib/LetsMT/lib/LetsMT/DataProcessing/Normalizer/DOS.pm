package LetsMT::DataProcessing::Normalizer::DOS;

=head1 NAME

LetsMT::DataProcessing::Normalizer::DOS

=head1 DESCRIPTION

Remove DOS-type line endings

=cut

use strict;
use parent 'LetsMT::DataProcessing::Normalizer';


sub normalize_no_copy {
    $_[1] =~ s/\c\r//gs;
    $_[1] =~ s/\f/\n/gs;
    $_[1] =~ s/\x{000D}//gs;  # cr in unicode
    $_[1] =~ s/\x{000A}//gs;  # line feed in unicode
    $_[1] =~ s/\x{000C}/\n/gs;  # form feed in unicode
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