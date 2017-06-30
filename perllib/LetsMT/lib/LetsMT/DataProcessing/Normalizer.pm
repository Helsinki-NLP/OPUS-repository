package LetsMT::DataProcessing::Normalizer;

=head1 NAME

LetsMT::DataProcessing::Normalizer

=head1 DESCRIPTION

Derivative classes must implement C<normalize_no_copy>.

=cut

use strict;

use LetsMT::DataProcessing::Normalizer::Chain;
use LetsMT::DataProcessing::Normalizer::Whitespace;
use LetsMT::DataProcessing::Normalizer::SeparateHeader;
use LetsMT::DataProcessing::Normalizer::Ligatures;
use LetsMT::DataProcessing::Normalizer::DOS;
use LetsMT::DataProcessing::Normalizer::Moses;
use LetsMT::DataProcessing::Normalizer::No;

# map types to normalizer objects
our $TYPE_TO_NORMALIZER = {
    whitespace  => new LetsMT::DataProcessing::Normalizer::Whitespace,
    header      => new LetsMT::DataProcessing::Normalizer::SeparateHeader,
    ligatures   => new LetsMT::DataProcessing::Normalizer::Ligatures,
    dos         => new LetsMT::DataProcessing::Normalizer::DOS,
    moses       => new LetsMT::DataProcessing::Normalizer::Moses
};
$$TYPE_TO_NORMALIZER{space} = $$TYPE_TO_NORMALIZER{whitespace};


=head1 CONSTRUCTOR

 $normalizer = new LetsMT::DataProcessing::Normalizer ( type => $types )

C<$types> can be a comma-separated list of normalizer types.

=cut

sub new {
    my $class = shift;
    my %self  = @_;

    # if this is in the base class: select normalizer
    if ( $class eq 'LetsMT::DataProcessing::Normalizer' ) {
        if ( $self{type} ) {
            # type can be a (comma spearated) list of normalizer types
            my @types = split( /\,/, $self{type} );
            my @norm = ();
            foreach (@types) {
                if ( exists $$TYPE_TO_NORMALIZER{$_} ) {
                    push( @norm, $$TYPE_TO_NORMALIZER{$_} );
                }
            }

            # more than one? --> make a chain
            if ( scalar @norm > 1 ) {
                return new LetsMT::DataProcessing::Normalizer::Chain(@norm);
            }

            # only one? --> return it
            return $norm[0] if ( scalar @norm );
        }

        # no normalization ....
        return new LetsMT::DataProcessing::Normalizer::No;
    }

    # this is to inherit by child classes
    return bless \%self, $class;
}


=head1 METHODS

=head2 C<normalize_no_copy>

 $normalizer->normalize_no_copy ($string)

Normalize C<$string> destructively (the original string passed as parameter is changed).

Abstract method, must be overridden!
It is also used by the inherited copying method C<normalize>.

=cut

sub normalize_no_copy {
    warn "Nothing in base-class!";
}


=head2 C<normalize>

 $normalized_string = $normalizer->normalize ($string)

Normalize a copy of C<$string> and return it.

Use C<normalize_no_copy> instead if the original string is not needed.

=cut

sub normalize {
    my $self = shift;
    my ($string) = @_;
    $self->normalize_no_copy($string);
    return $string;
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