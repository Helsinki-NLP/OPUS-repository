package LetsMT::DataProcessing::Tokenizer::No;

=head1 NAME

LetsMT::DataProcessing::Tokenizer::No - dummy that doesn't do a thing

=head1 IMPLEMENTS

=head2 C<tokenize>

=head2 C<detokenize>

=cut

use strict;
use parent 'LetsMT::DataProcessing::Tokenizer';


sub tokenize {
    return $_[1];
}


sub detokenize {
    return $_[1][0] if (ref($_[1]) eq 'ARRAY');
    return $_[1];
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