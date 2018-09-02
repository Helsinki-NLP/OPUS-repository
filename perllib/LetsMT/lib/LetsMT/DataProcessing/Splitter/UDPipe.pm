package LetsMT::DataProcessing::Splitter::UDPipe;

=head1 NAME

LetsMT::DataProcessing::Splitter::UDPipe

=head1 DESCRIPTION

Use UDPipe to split text into sentences.

=cut

use strict;
use parent 'LetsMT::DataProcessing::Splitter';

use LetsMT::DataProcessing::UDPipe;

my $DEFAULT_LANG = 'en';
my $UDPIPE = new LetsMT::DataProcessing::UDPipe;

sub new {
    my $class = shift;
    my %self  = @_;
    $self{lang} = $DEFAULT_LANG unless ( defined $self{lang} );
    $UDPIPE->load_model($self{lang});
    return bless \%self, $class;
}


sub split {
    my $self = shift;
    my @lines = @_;

    my $str;

    ## keep separate lines: do not merge with space!
    ## --> no sentences beyond line breaks!
    if ( $self->{separate_lines} ) {
        $str = join( "\n", @lines );
        $str =~ s/^\s*//s;
    }
    else {
        ## add newlines to empty lines to force sentence breaks between strings
        map( s/^(\s*)\n?$/$1\n/, @lines );

        # (but remove leading blanks to avoid empty sentences ....)
        $str = join( ' ', @lines );
        $str =~ s/^\s*//s;
    }

    ## split the joined text string
    my $sents = $UDPIPE->sentence_splitter($str);
    return @{$sents} if ( ref($sents) eq 'ARRAY' );
    return $str;
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
