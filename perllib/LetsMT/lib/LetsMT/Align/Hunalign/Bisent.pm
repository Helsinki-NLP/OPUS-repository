package LetsMT::Align::Hunalign::Bisent;

=head1 NAME

LetsMT::Align::Hunalign::Bisent - Sentence-align with C<hunalign> in 'bisent' mode

=head1 DESCRIPTION

Sentence-align two resources using the external tool C<hunalign>.
The difference to LetsMT::Align::Hunalign is
that it is run in bisent mode and, therefore,
extracts the links in a slightly different way.

=cut

use strict;
use parent 'LetsMT::Align::Hunalign';

# our $HUNPARA = '-realign -bisent';


=head1 CONSTRUCTOR

 $aligner = new LetsMT::Align (method => 'bisent', %params)

=cut


sub new {
    my ($class, %args) = @_;
    my $this = $class->SUPER::new(%args);
    $$this{para} .= ' -bisent';
    return bless($this, $class);
}


# sub new {
#     my $class = shift;
#     my %args  = @_;

#     $args{para}    = $args{para} || $HUNPARA;
#     my $self       = $class->SUPER::new(%args);
#     # $self->{para} .= ' -bisent';

#     return bless $self, $class;
# }


=head2 C<_hunalign2links>

Parse hunalign output and extract sentence links.
The difference between this link extraction and the one from the standard Hunalign module is
that this one only extracts one-to-one sentence alignments.

=cut


sub _hunalign2links {
    my $self = shift;
    my ( $output, $srcids, $trgids, $links ) = @_;

    my $totalScore = 0;

    foreach (@$output) {
        chomp;

        ## skip lines that do not start with a digit
        next if ( !/^[0-9]/ );

        ## split the line
        my ( $sid, $tid, $score ) = split(/\s+/);

        # TODO: why can this happen ....?
        next if ($sid > $#{$srcids});
        next if ($tid > $#{$trgids});

        # TODO: do we have to check wheather both are <p>?
        next if ( $$srcids[$sid] eq 'p' );
        next if ( $$trgids[$tid] eq 'p' );

	next unless ($$srcids[$sid] || $$trgids[$tid]);

	if ($score < $self->{scorethr} ){
	    $self->{NrSkippedLinks}++;
	    $self->{NrSkippedSrcSents}++;   # this does not work
	    $self->{NrSkippedTrgSents}++;   # only counts this sentence
	}
	else{
	    ## add links
	    my $idx = @{$links};
	    @{ $links->[$idx]->{src} } = ( $$srcids[$sid] );
	    @{ $links->[$idx]->{trg} } = ( $$trgids[$tid] );
	    $links->[$idx]->{score} = $score;
	    $totalScore += $score;
	}
    }

    if ($#{$output}){
        return $totalScore/$#{$output};
    }
    return 0;
}




package LetsMT::Align::Hunalign::Bisent::Cautious;

use parent 'LetsMT::Align::Hunalign::Bisent';
my $HUNPARA = '-realign -bisent -cautious';

sub new {
    my ($class, %args) = @_;
    my $this = $class->SUPER::new(%args);
    $$this{para} .= ' -cautious';
    return bless($this, $class);
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
