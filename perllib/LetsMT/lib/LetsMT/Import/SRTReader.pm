package LetsMT::Import::SRTReader;

=head1 NAME

LetsMT::Import::SRTReader - reader for C<srt> files

=head1 DESCRIPTION

SRT: SubRip Text - a plain-text format for video subtitles.

A child of L<LetsMT::Import::TextReader|LetsMT::Import::TextReader>.

=cut

use strict;
use parent 'LetsMT::Import::TextReader';


=head1 METHOD

=head2 C<read>

=cut

sub read {
    my $self   = shift;
    my $before = shift || {};  # optional hash structures for data before
    my $after  = shift || {};  # and after the current text chunk (par-breaks)

    my $fh = $self->{fh};
    my $id = undef;

    my $start = undef;
    my $end   = undef;
    my $text  = undef;

    while ( my $line = <$fh> ) {
        $line =~ s/\r\n$/\n/;

        if ( !defined $id ) {
            if ( $line =~ /^\s*([0-9]+)$/ ) {
                $id = $1;
                next;
            }
        }

        ## time information
        if ( $line =~ /^([0-9:,]+) --> ([0-9:,]+)/ ) {
            $start = $1;
            $end   = $2;
        }

        # this is the end of the chunk
        elsif ( $line =~ /^\s*$/ ) { last; }

        # concatenate strings
        else { $text .= $line; }
    }

    # nothing more to read
    return undef unless ($text);

    ## TODO: we should put the fixes below into normalizers!

    # some strange markup in curly brackets in some files
    $text =~ s/\{.*?\}\#?//gs;
    ## replace 2x single quote with double quotes
    $text =~ s/\'\'/\"/g;
    ## found in eng/Comedy/1995/1690_84526_112988_four_rooms.xml.gz:
    ## 2 double quotes ...
    $text =~ s/\"\"+/\"/g;
    ## ignore formatting tags!
    $text =~ s/\<[^\>]+\>//gs;

    $self->{normalizer}->normalize_no_copy($text);

    ## split and tokenize the text
    my @sentences = $self->{splitter}->split($text);
    my @tokenized = ();
    foreach (@sentences) {
        push( @tokenized, $self->{tokenizer}->tokenize($_) );
    }

    # create time stamp markup
    %{$before} = ();
    %{$after}  = ();

    push(
        @{ $$before{ $self->{lang} } },
        [ 'time', { id => "T${id}S", value => $start } ]
    );
    push(
        @{ $$after{ $self->{lang} } },
        [ 'time', { id => "T${id}E", value => $end } ]
    );

    # return data
    $self->{id}++;
    return { $self->{lang} => { $self->{id} => \@tokenized } };
}


=head1 CLASS METHOD

=head2 C<_time2sec>

=cut

sub _time2sec {
    my $time = shift;
    my ( $h, $m, $s, $ms ) = split( /[^0-9\-]/, $time );
    my $sec = 3600 * $h + 60 * $m + $s + $ms / 1000;
    return $sec;
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