package LetsMT::Import::TextReader;

=head1 NAME

LetsMT::Import::TextReader - reader for plain-text files

=cut

use strict;
use Data::Dumper;

use LetsMT::Import;
use LetsMT::WebService;
use LetsMT::Tools qw(:all);

# read lines with length limit
# (this is much faster than the getc implementation LetsMT::Tools)
# (File::fgets is even faster but ignores Perl I/O layers)
use File::GetLineMaxLength;  


# max line length = 1048576 characters
# max number of lines kept in buffer = 1000
# (TODO: should we allow more?)

our $MAX_LINE_LENGTH = 2**16;
our $MAX_NR_LINES    = 1000;


=head1 CONSTRUCTOR

 $reader = new LetsMT::Import::TextReader (%OPTIONS)

Create a new instance of C<LetsMT::Import::TextReader>,
which is guaranteed to have the fields C<tokenizer>, C<normalizer>, C<splitter> and C<lang>.
If no such keys are provided in the supplied C<%hash>, the defaults in C<LetsMT::Import> are used.

All sentences begin read are returned as if they are in language C<lang>.
This has consequences for the way they are written with C<LetsMT::Import::XCESWriter>.

=cut

sub new {
    my $class = shift;
    my %self  = @_;

    $self{tokenizer}  = $LetsMT::Import::DEFAULT_TOKENIZER  unless ( defined $self{tokenizer} );
    $self{normalizer} = $LetsMT::Import::DEFAULT_NORMALIZER unless ( defined $self{normalizer} );
    $self{splitter}   = $LetsMT::Import::DEFAULT_SPLITTER   unless ( defined $self{splitter} );
    #TODO: a warning should be given if no language is set:
    $self{lang}       = $LetsMT::Import::DEFAULT_LANG       unless ( defined $self{lang} );

    return bless \%self, $class;
}


=head1 METHODS

=head2 C<open>

=cut

sub open {
    my $self = shift;
    my $resource = shift || $self->{resource};

    # Get requested resource if necessary
    if ( ( !-e $resource->local_path ) || $self->{-always_fetch} ) {
        return 0 unless ( &LetsMT::WebService::get_resource($resource) );
    }

    $self->{fh}     = &LetsMT::Tools::open_bom_file( $resource->local_path );
    $self->{reader} = File::GetLineMaxLength->new($self->{fh});
    $self->{id}     = 0;
    $self->{buffer} = [];
    $self->{finished} = 0;
    return $self->{fh};
}


=head2 C<read>

 $reader->read

 $reader->read ($before, $after)

... optional hash structures for data before and after the current text chunk (par-breaks).

Monolingual sentence "pair" structure:

 {
     lang => {
         id => [ token1, token2, ..., tokenN ]
     }
 }

Before and after markup structures:

 {
     lang => [
         "plain text",
         [open-tag, {attr1 => 1, ... } ],
         [close-tag],
     ]
 }

=cut

sub read {
    my $self   = shift;
    my $before = shift || {};  # optional hash structures for data before
    my $after  = shift || {};  # and after the current text chunk (par-breaks)

    my $line;

    # reset before/after hashs
    %{$before} = ();
    %{$after}  = ();

    # split if there is still something in the buffer
    my @sentences = ();
    if ( $#{ $self->{buffer} } > 0 ) {
        @sentences = $self->{splitter}->split( @{ $self->{buffer} } );
    }

    my $ParBreak = 0;

    # read more if necessary
    while ( $#sentences < 1 ) {
        # if ( defined( my $line = readline $self->{fh} ) ) {
        # if ( defined( my $line = fgets( $self->{fh}, $MAX_LINE_LENGTH ) ) ) {
	if (my $line = $self->{reader}->getline( $MAX_LINE_LENGTH ) ) {

            # if we have an empty line --> paragraph break!
            $ParBreak = 1 if ($line!~/\S/);

            $self->{normalizer}->normalize_no_copy($line);
            push @{ $self->{buffer} }, $line;
            if ( $#{ $self->{buffer} } ) {
                @sentences = $self->{splitter}->split( @{ $self->{buffer} } );
            }
        }
        else { last; }

        # stop if we exceed a certain number of lines in the buffer
        last if ( $#{ $self->{buffer} } >= $MAX_NR_LINES );
    }

    # let's create the data structures for markup before and after the
    # current sequence of sentences (paragraph breaks)

    ## create a new paragraph before the first sentence!
    if ($self->{id} == 0){
        # need to close previous paragraph
        if ($self->{openPar}){
            push(@{$$before{$self->{lang}}},[ 'p' ]);
        }
        # open a new one
        push(@{$$before{$self->{lang}}},
             [ 'p', { id => ++$self->{pid} } ] );
        $self->{openPar} = 1;
    }

    ## add a paragraph after the current sequence of sentences
    if ($ParBreak){
        # need to close previous paragraph
        if ($self->{openPar}){
            push(@{$$after{$self->{lang}}},[ 'p' ]);
        }
        # open a new one
        push(@{$$after{$self->{lang}}},
             [ 'p', { id => ++$self->{pid} } ] );
        $self->{openPar} = 1;
    }

    # no sentences found so far?
    # --> check if there is still something in the buffer to be converted
    unless ( scalar @sentences ) {
        if ( scalar @{ $self->{buffer} } ) {
            @sentences = $self->{splitter}->split( @{ $self->{buffer} } );
        }
    }

    # return nothing if no more sentences found
    return undef unless ( scalar @sentences );

    # return data otherwise
    $self->{id}++;
    $self->{buffer} = \@sentences;
    return {
        $self->{lang} => {
            $self->{id} => [
                $self->{tokenizer}->tokenize( shift @{ $self->{buffer} } )
            ]
        }
    };
}


=head2 C<read_old> (obsolescent)

C<read_old> always split incoming lines ---> leads to long sentences
that should be split on double new lines (or empty lines)

=cut

sub read_old {
    my $self = shift;
    my $line;
    while ( scalar @{ $self->{buffer} } < 2 && !$self->{finished} ) {
        if ( defined( my $line = readline $self->{fh} ) ) {
            $self->{normalizer}->normalize_no_copy($line);
            if ( scalar @{ $self->{buffer} } ) {
                push @{ $self->{buffer} },
                    $self->{splitter}
                    ->split( pop @{ $self->{buffer} }, $line );
            }
            else {
                push @{ $self->{buffer} }, $self->{splitter}->split($line);
            }
        }
        else {
            $self->{finished} = 1;
        }
    }

    return undef unless ( scalar @{ $self->{buffer} } );
    $self->{id}++;
    return {
        $self->{lang} => {
            $self->{id} => [
                $self->{tokenizer}->tokenize( shift @{ $self->{buffer} } )
            ]
        }
    };
}


=head2 $reader->close

=cut

sub close {
    my $self = shift;
    close $self->{fh};
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
