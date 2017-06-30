package LetsMT::DataProcessing::Tokenizer::UPlug;

=head1 NAME

LetsMT::DataProcessing::Tokenizer::UPlug

=head1 IMPLEMENTS

=head2 C<detokenize>

=cut

use strict;
use parent 'LetsMT::DataProcessing::Tokenizer::Whitespace';


sub tokenize {
    my $self = shift;
    my ($string) = @_;

    # non-P + P + (P or \s or \Z)
    $string =~ s/(\P{P})(\p{P}[\p{P}\s]|\p{P}\Z)/$1 $2/gs;

    # (\A or P or \s) + P + non-P
    $string =~ s/(\A\p{P}|[\p{P}\s]\p{P})(\P{P})/$1 $2/gs;

    # special treatment for ``
    $string =~ s/(``)(\S)/$1 $2/gs;

    # separate punctuations if they are not the same
    # (use negative look-ahead for that!)
    $string =~ s/(\p{P})(?!\1)/$1 $2/gs;

    return $self->SUPER::tokenize($string);
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