package LetsMT::DataProcessing::Normalizer::Chain;

=head1 NAME

LetsMT::DataProcessing::Normalizer::Chain

=head1 DESCRIPTION

Execute a chain of other Normalizers on the data.

=cut

use strict;
use parent 'LetsMT::DataProcessing::Normalizer';


sub new {
    my $class = shift;
    my @self  = @_;
    return bless \@self, $class;
}


sub normalize_no_copy {
    my $self = shift;
    foreach (@$self) {
        $_->normalize_no_copy(@_);
    }
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