package LetsMT::DataProcessing::Tokenizer;

=head1 NAME

LetsMT::DataProcessing::Tokenizer

=head1 DESCRIPTION

Splits a sentence into tokens.

Derivative classes should implement C<tokenize> or C<detokenize> (or both) depending on the intended usage.
These are gathered into one class because they may rely on shared information.

=head1 METHODS

=cut

use strict;

use LetsMT::DataProcessing::Tokenizer::No;
use LetsMT::DataProcessing::Tokenizer::Whitespace;
use LetsMT::DataProcessing::Tokenizer::UPlug;
use LetsMT::DataProcessing::Tokenizer::Europarl;


=head1 CONSTRUCTOR

 $tokenizer = new LetsMT::DataProcessing::Tokenizer( method => $method )

=cut

sub new {
    my $class = shift;
    my %self  = @_;

    # if this is in the base class: select a tokenizer
    if ( $class eq 'LetsMT::DataProcessing::Tokenizer' ) {
        if ( $self{method} =~ /europarl/i ) {
            return new LetsMT::DataProcessing::Tokenizer::Europarl(@_);
        }
        elsif ( $self{method} =~ /u?plug/i ) {
            return new LetsMT::DataProcessing::Tokenizer::UPlug(@_);
        }
        elsif ( $self{method} =~ /(white)?space/i ) {
            return new LetsMT::DataProcessing::Tokenizer::Whitespace(@_);
        }

        # default: no tokenization
        return new LetsMT::DataProcessing::Tokenizer::No(@_);
    }

    # otherwise: bless the class
    return bless \%self, $class;
}


=head1 METHODS

=head2 C<tokenize>

 @tokens = $tokenizer->tokenize ($string)

Turns a string into a list of tokens.

Abstract method, must be overridden!

=cut

sub tokenize {
    warn "Nothing in base-class!";
}



=head2 C<detokenize>

 $string = $tokenizer->detokenize(\@tokens)

Turns a reference to a list of tokens into a string.

Abstract method, must be overridden!

=cut

sub detokenize {
    warn "Nothing in base-class!";
}


=head2 C<tokenize_data>

 $string = $tokenizer->tokenize_data(\%data)

Tokenizes data given in a data structure

=cut


sub tokenize_data {
    my $self = shift;
    my $data = shift;

    if ( ref($data) eq 'HASH') {
        foreach my $l ( keys %{$data} ) {
            if ( ref($$data{$l}) eq 'ARRAY' ) {
                foreach ( 0 .. $#{$$data{$l}} ) {
                    my @tok = $self->tokenize( $$data{$l}[$_] );
                    $$data{$l}[$_] = [];
                    @{ $$data{$l}[$_] } = @tok;
                }
            }
            elsif ( ref($$data{$l}) eq 'HASH' ) {
                foreach my $k ( keys %{$$data{$l}} ) {
                    # already an array? --> try to tokenize each element
                    if ( ref($$data{$l}{$k}) eq 'ARRAY') {
                        my @tok=();
                        map( push( @tok,$self->tokenize($_) ), 
                             @{$$data{$l}{$k}} );
                        @{$$data{$l}{$k}} = @tok;
                    }
                    else{
                        my @tok = $self->tokenize( $$data{$l}{$k} );
                        $$data{$l}{$k} = [];
                        @{ $$data{$l}{$k} } = @tok;
                    }
                }
            }
            else{
                return $self->tokenize($$data{$l});
            }
        }
    }
    else {
        return $self->tokenize($data);
    }
    return $data;
}


=head2 C<detokenize_data>

 $string = $tokenizer->detokenize_data( \%data )

Tokenizes data given in a data structure

=cut

sub detokenize_data {
    my $self = shift;
    my $data = shift;

    if ( ref($data) eq 'HASH') {
        foreach my $l ( keys %{$data} ) {

            if ( ref($$data{$l}) eq 'ARRAY' ) {
                foreach ( 0 .. $#{$$data{$l}} ) {
                    $$data{$l}[$_] = $self->detokenize( $$data{$l}[$_] );
                }
            }
            elsif ( ref($$data{$l}) eq 'HASH' ) {
                foreach ( keys %{$$data{$l}} ) {
                    $$data{$l}{$_} = $self->detokenize( $$data{$l}{$_} );
                }
            }
            else {
                return $self->detokenize($$data{$l});
            }
        }
    }
    else {
        return $self->detokenize($data);
    }
    return $data;
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