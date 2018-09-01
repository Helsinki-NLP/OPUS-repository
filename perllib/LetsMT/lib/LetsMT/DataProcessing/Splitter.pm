package LetsMT::DataProcessing::Splitter;

=head1 NAME

LetsMT::DataProcessing::Splitter

=head1 DESCRIPTION

Split texts into sentences.

Derivative classes should implement C<split>.

=cut

use strict;

use LetsMT::DataProcessing::Splitter::No;
use LetsMT::DataProcessing::Splitter::Lingua;
use LetsMT::DataProcessing::Splitter::Europarl;
use LetsMT::DataProcessing::Splitter::UDPipe;
# use LetsMT::DataProcessing::Splitter::OpenNLP;


=head1 CONSTRUCTOR

 $splitter = new LetsMT::DataProcessing::Splitter (%OPTIONS)

OPTIONS:

 method ........... (possible values: europarl, lingua, or opennpl;
                     default: no splitting)
 lang ............. Language code (default/fallback: en)
 separate_lines ... Keep separate lines in input? (default: false)

=cut

sub new {
    my $class = shift;
    my %self  = @_;

    # if this is in the base class: select a tokenizer
    if ( $class eq 'LetsMT::DataProcessing::Splitter' ) {

        if ( $self{method} =~ /europarl/i ) {
            return new LetsMT::DataProcessing::Splitter::Europarl(@_);
        }
        elsif ( $self{method} =~ /lingua/i ) {
            return new LetsMT::DataProcessing::Splitter::Lingua(@_);
        }
        elsif ( $self{method} =~ /udpipe/i ) {
            return new LetsMT::DataProcessing::Splitter::UDPipe(@_);
        }
        elsif ( $self{method} =~ /opennlp/i ) {
	    ## load on demand with require (to avoid mod_perl load errors)
	    require LetsMT::DataProcessing::Splitter::OpenNLP;
            return new LetsMT::DataProcessing::Splitter::OpenNLP(@_);
        } else {  # default: no splitting
            return new LetsMT::DataProcessing::Splitter::No(@_);
        }

    }

    # otherwise: bless the class
    return bless \%self, $class;
}


=head1 METHODS

=head2 C<split>

 ( s_1, s_2, ..., s_n ) = $splitter->split (f_1, f_2, ..., f_m)

where C<s_i> is an identified sentence and C<f_i> is a text fragment.

Turn a list of text fragments into a list of sentences
(where it is not certain that the last one is a proper sentence,
since there might be a missing fragment).

Uses consecutive calls passing the last sentence of one call
as the first fragment of the next call.

Abstract method, must be overridden!

=cut

sub split {
    warn "Nothing in base class!";
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
