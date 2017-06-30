package LetsMT::Import::MosesReader;

=head1 NAME

LetsMT::Import::MosesReader - reader for I<Moses> files

=head1 DESCRIPTION

L<Moses|http://www.statmt.org/moses/>:
plain-text data used for statistical machine translation systems.

=cut

use strict;

use File::Basename;
use Data::Dumper;

use LetsMT::Import;
use LetsMT::Tools;
use LetsMT::Import::TextReader;
use LetsMT::DataProcessing::Normalizer::Whitespace;
use LetsMT::Lang::ISO639 qw(iso639_exists iso639_AnyToTwo);


=head1 CLASS VARIABLE (public)

=head2 C<$DEFAULT_NORMALIZER>

An instance of the L<whitespace normalizer|LetsMT::DataProcessing::Normalizer::Whitespace>.

=cut

our $DEFAULT_NORMALIZER = new LetsMT::DataProcessing::Normalizer::Whitespace;


=head1 CONSTRUCTOR

 $reader = new LetsMT::Import::TextReader (%OPTIONS)

Creates a new instance of C<LetsMT::Import::TextReader>,
which is guaranteed to have the fields C<tokenizer>, C<normalizer>, C<splitter> and C<lang>.
For any key not provided in the supplied C<%OPTIONS>, the defaults in C<LetsMT::Import> are used.

All sentences begin read are returned as if they are in language C<lang>.
This has consequences for the way they are written with C<LetsMT::Import::XCESWriter>.

=cut

sub new {
    my $class = shift;
    my %self  = @_;

    $self{tokenizer} = $LetsMT::Import::DEFAULT_TOKENIZER
        unless ( defined $self{tokenizer} );
    $self{normalizer} = $DEFAULT_NORMALIZER
        unless ( defined $self{normalizer} );
    $self{splitter} = $LetsMT::Import::DEFAULT_SPLITTER
        unless ( defined $self{splitter} );

    return bless \%self, $class;
}


=head1 METHODS

=head2 C<open>

 $reader->open ($resource)

Open the resource C<$resource> for reading.

=cut

sub open {
    my $self      = shift;
    my @resources = @_;

    # create text reader for each resource provided
    my $fh;
    $self->{reader} = [];
    foreach my $r ( 0 .. $#resources ) {

        # get language IDs
        my $lang = undef;
        my $file = $resources[$r]->local_path;
        if ( $file =~ /\.([^\.]+)$/ ) {
            my $id = $1;
            if ( iso639_exists($id) ) {
                $lang = iso639_AnyToTwo($id);
            }
        }

        # no lang ID found? --> simply number all resources
        $lang = $self->{lang} . $r unless $lang;

        $self->{reader}->[$r] = new LetsMT::Import::TextReader(
            tokenizer  => $self->{tokenizer}  || $LetsMT::Import::DEFAULT_TOKENIZER,
            normalizer => $self->{normalizer} || $LetsMT::Import::DEFAULT_NORMALIZER,
            splitter   => $self->{splitter}   || $LetsMT::Import::DEFAULT_SPLITTER,
            lang => $lang,
        );
        $fh = $self->{reader}->[$r]->open( $resources[$r] );
    }
    return $fh;
}


=head2 C<read>

 $reader->read

=cut

sub read {
    my $self = shift;
    my $ap;

    if ( @{ $self->{reader} } ) {
        if ( $ap = $self->{reader}->[0]->read() ) {
            foreach my $r ( 1 .. $#{ $self->{reader} } ) {
                if ( my $data = $self->{reader}->[$r]->read() ) {
                    foreach ( keys %{$data} ) {
                        $$ap{$_} = $$data{$_};
                    }
                }
            }
        }
        return $ap;
    }
    return undef;
}


=head2 C<close>

 $reader->close

Close all text readers.

=cut

sub close {
    my $self = shift;
    foreach my $r ( 0 .. $#{ $self->{reader} } ) {
        $self->{reader}->[$r]->close;
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