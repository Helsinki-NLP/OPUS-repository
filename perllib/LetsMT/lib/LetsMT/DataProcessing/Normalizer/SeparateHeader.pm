package LetsMT::DataProcessing::Normalizer::SeparateHeader;

=head1 NAME

LetsMT::DataProcessing::Normalizer::SeparateHeader

=head1 DESCRIPTION

Separate headers from the rest of the text.

=cut

use strict;
use parent 'LetsMT::DataProcessing::Normalizer';


# header-length-threshold = 25 characters (shorter ==> header)

my $DEFAULT_HEADER_LENGTH = 25;


sub new {
    my $class = shift;
    my %self  = @_;
    $self{header_length} = $DEFAULT_HEADER_LENGTH
        unless ( defined $self{header_length} );
    return bless \%self, $class;
}


sub normalize_no_copy {
    $_[1] =~ s/^(\S.{0,$_[0]->{header_length}})$/$1\n/;
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