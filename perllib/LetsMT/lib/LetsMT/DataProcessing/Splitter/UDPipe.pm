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

    ## join all lines and split on empty lines
    ## separate_lines: keep lines separate as they are
    unless ( $self->{separate_lines} ) {
	my $str = join( "\n", @lines );
	# @lines = split( /\n\s*\n/, $str );
	@lines = split( /\n\s+/, $str );
    }

    my @sents = ();
    foreach my $str (@lines){
	my $new = $UDPIPE->sentence_splitter($str);
	if ( ref($new) eq 'ARRAY' ){
	    push(@sents, @{$new});
	}
	else {
	    push(@sents, $str);
	}
    }
    return @sents;
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
