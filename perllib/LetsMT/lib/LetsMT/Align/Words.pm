package LetsMT::Align::Words;

=head1 NAME

LetsMT::Align::Words - word alignment

=head1 DESCRIPTION

A factory class to return an object instance of a selected alignment module.

=cut

use strict;

use LetsMT::Align::Words::Eflomal;


=head1 CONSTRUCTOR

 $aligner = new LetsMT::Align::Words

=cut

sub new {
    my $class = shift;
    return new LetsMT::Align::Words::Eflomal(@_);
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
