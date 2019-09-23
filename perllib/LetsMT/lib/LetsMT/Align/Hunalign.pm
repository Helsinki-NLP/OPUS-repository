package LetsMT::Align::Hunalign;

=head1 NAME

LetsMT::Align::Hunalign - Sentence-align with C<hunalign>

=head1 DESCRIPTION

Sentence-align two resources using the external tool C<hunalign>.

=cut

use strict;
use parent 'LetsMT::Align';

use Log::Log4perl qw(get_logger :levels);

use LetsMT::Align::GaleChurch;
use LetsMT::Export::Reader;
use LetsMT::Export::Writer;
use LetsMT::Export::Writer::XCES;
use LetsMT::Tools;
use LetsMT::WebService;

use File::Temp 'tempfile';
use File::ShareDir qw(dist_dir);

# default locations and parameters for hunalign

our $HUNALIGN = undef;

## the recommended options for post-filtering do not seem to worl well
## (-ppthresh=30 -headerthresh=100 -topothresh=30)
## TODO: integrate language-specific dictionaries
##       (and timeout like in uplug-hunalign)

our $HUNDIC      =  dist_dir('LetsMT').'/hunalign/null.dic';
our @BASE_PARAMS = ('-utf');                                                   # required parameter
our $HUNPARA     = '-realign';                                                 # additional hunalign parameters
# our $HUNPARA     = '-realign -ppthresh=30 -headerthresh=100 -topothresh=30';   # additional hunalign parameters


###-------------------------------------------------------------------------
### possible hunalign parameters:
#
# -bisent
#     Only bisentences (one-to-one alignment segments) are printed.
#     In non-text mode, their starting rung is printed.
#
# -cautious
#     In -bisent mode, only bisentences for which both the preceding
#     and the following segments are one-to-one are printed.
#     In the default non-bisent mode, only rungs
#     for which both the preceeding and the following segments
#     are one-to-one are printed.
#
# -realign
#     If this option is set, the alignment is built in three phases.
#     After an initial alignment, the algorithm heuristically adds items
#     to the dictionary based on cooccurrences in the identified bisentences.
#     Then it re-runs the alignment process based on this larger dictionary.
#     This option is recommended to achieve the highest possible alignment 
#     quality. It is not set by default because it approximately
#     triples the running time while the quality improvement it
#     yields are typically small.
#
# -thresh=n
#     Don't print out segments with score lower than n/100.
#
# -ppthresh=n
#     Filter rungs with less than n/100 average score in their vicinity.
#
# -headerthresh=n
#     Filter all rungs at the start and end of texts until finding a reliably
#     plausible region.
#
# -topothresh=n
#     Filter rungs with less than n percent of one-to-one segments
#     in their vicinity.
#
#  All these 'thresh' values default to zero (i.e., no postfiltering). Typical sensible values are 
#      -ppthresh=30 -headerthresh=100 -topothresh=30 
#  and *are* recommended over the default. Of course the optimal parameter values depend on the 
#  nature of the bitext, and also depend on the coverage of the dictionary somewhat.
#
# - Ladder format of alignments. Alignments are described by a newline-separated
#   list of pairs of integers represented by the first two columns of the ladder
#   file. Such a pair is called a rung. The first coordinate denotes a position in
#   the source language, the second coordinate denotes a position in the target
#   language. A rung (n,m) means the following: The first n sentences of the
#   source text correspond to the first m sentences of the target text. The rungs
#   cannot intersect (e.g., (10,12) (11,10) is not allowed), which means that the
#   order of sentences are preserved by the alignment. The first rung is always
#   (0,0), the last one is always
#   (sentenceNumber(sourceText),sentenceNumber(targetText)). The third column of
#   the ladder format is a confidence value for the segment starting with the
#   given rung. The columns of the ladder file are separated by a tab.
#
# -Dictionary:
#
# The dictionary consists of newline-separated dictionary items. An item
# consists of a target languge phrase and a source language phrase, separated by
# the " @ " sequence. Multiword phrases are allowed. The words of a phrase are
# space-separated as usual. IMPORTANT NOTE: In the current version, for
# historical reasons, the target language phrases come first. So the ordering is
# the opposite of the ordering of the command-line arguments or the results.
###-------------------------------------------------------------------------


=head1 CONSTRUCTOR

 $aligner = new LetsMT::Align (method => 'hunalign', %params)

=cut

sub new {
    my $class = shift;
    my %self  = @_;

    unless ($HUNALIGN){
	$HUNALIGN = `which hunalign`;
	chomp($HUNALIGN);
    }

    # if hunalign is not found
    # --> use Gale&Church as fall back!
    unless ($HUNALIGN) {
        get_logger(__PACKAGE__)
            ->warn("hunalign is not found! Fall-back to Gale&Church");
        return new LetsMT::Align::GaleChurch(@_);
    }

    ## save given arguments to save them later in metadata
    %{ $self{args} } = @_;

    ## allow to overwrite defaults ....

    $self{hunalign} = $self{hunalign} || $HUNALIGN;
    $self{dic}      = $self{dic}      || $HUNDIC;
    $self{para}     = $self{para}     || $HUNPARA;

    ## filter alignments with scores below scorethr
    $self{scorethr} = -10 unless $self{scorethr};

    ## maximum number of sentences in alignments
    $self{maxsrc} = 2 unless $self{maxsrc};
    $self{maxtrg} = 2 unless $self{maxtrg};

    return bless \%self, $class;
}


=head1 METHODS

=head2 C<align>

 $AlgRes = align ($SrcRes, $TrgRes [, $AlgRes])

Align C<$SrcRes> and C<$TrgRes> with each other and save sentence alignments in C<$AlgRes>.
If no C<$AlgRes> is given:
Create a new resource from the information found in C<$SrcRes>, C<$TrgRes>
(see C<LetsMT::Align::make_align_resource>).

=cut

sub align {
    my $self = shift;
    my ( $SrcResource, $TrgResource, $AlgResource ) = @_;

    # swap if needed (language IDs should be sorted)
    if ( $SrcResource->language() gt $TrgResource->language() ) {
        ( $SrcResource, $TrgResource ) = ( $TrgResource, $SrcResource );
    }

    unless ( ref($AlgResource) ) {
        $AlgResource = &LetsMT::Align::make_align_resource( $SrcResource,
            $TrgResource );
    }

    my $srcids = [];
    my $trgids = [];
    my %DetectedLang = ();

    my $srcfile = $self->_resource2hunalign( $SrcResource, $srcids, \%DetectedLang );
    my $trgfile = $self->_resource2hunalign( $TrgResource, $trgids, \%DetectedLang );

    # TODO: it's stupid to always require splitting of parameters
    my @para = split(/\s+/,$self->{para});

    # run the actual alignment using hunalign

    my ( $success, $ret, $out, $err ) = &run_cmd(
        $self->{hunalign},
        @BASE_PARAMS,
        @para,
        $self->{dic},
        $srcfile,
        $trgfile
    );
    # if ($err=~/\nQuality\s+([0-9\.]+)(\Z|\s)/){
    #      $self->{AlignConfidence} = $1;
    # }

    ## not successfull? --> try to fall-back to Gale & Church alignment

    unless ($success){
        my $aligner = new LetsMT::Align::GaleChurch( %{$self->{args}} );
        return $aligner->align(@_);
    }

    # parse through the output and extract sentence links

    my @alignments = split (/\n/,$out);
    my @links = ();
    $self->_hunalign2links( \@alignments, $srcids, $trgids, \@links );

    if ($err =~ /(\A|\n)Quality\s+([0-9\.\-]+)(\Z|\n)/s){
        $self->{AlignConfidence} = $2;
    }

    # create the sentence alignment file
    $self->write_links($AlgResource, \@links, \%DetectedLang);

    # my $writer = new LetsMT::Export::Writer::XCES();
    # $writer->open($AlgResource);
    # $writer->open_document_pair( $AlgResource->fromDoc, $AlgResource->toDoc );

    # %{ $self->{LinkTypes} } = ();
    # $self->{NrLinks} = 0;

    # my ( $totalSrc, $totalTrg ) = ( 0, 0 );

    # $self->{SIZE} = 0;
    # foreach my $l (@links) {
    #     $l->{src} = [] unless ( ref( $l->{src} ) eq 'ARRAY' );
    #     $l->{trg} = [] unless ( ref( $l->{trg} ) eq 'ARRAY' );
    #     my $nrSrc = scalar @{ $l->{src} };
    #     my $nrTrg = scalar @{ $l->{trg} };
    #     next unless ( $nrSrc || $nrTrg );
    #     $totalSrc += $nrSrc;
    #     $totalTrg += $nrTrg;
    #     $self->{LinkTypes}->{"$nrSrc:$nrTrg"}++;
    #     $writer->write( $l->{src}, $l->{trg}, 'certainty' => $l->{score} );
    #     $self->{NrLinks}++;
    # }
    # $writer->close();

    # $self->{NrSrcSents} = $totalSrc;
    # $self->{NrTrgSents} = $totalTrg;

    # if ( $self->{verbose} ) {
    #     foreach ( keys %{ $self->{LinkTypes} } ) {
    #         print STDERR "type = $_: $self->{LinkTypes}->{$_} times\n";
    #     }
    #     print STDERR "$self->{NrLinks} links\n";
    #     print STDERR "$self->{NrSrcSents} source sentences\n";
    #     print STDERR "$self->{NrTrgSents} target sentences\n";
    #     printf STDERR "align confidence = %5.2f\n", $self->{AlignConfidence};
    # }

    return $AlgResource;
}


=head2 C<_hunalign2links>

Parse hunalign output and extract sentence links.

=cut

sub _hunalign2links {
    my $self = shift;
    my ( $output, $srcids, $trgids, $links ) = @_;

    my ( $prevSrc, $prevTrg, $totalScore, $prevScore ) = ( 0, 0, 0, 0 );

    ## TODO: why should we do this?
    ## add the final point of bitext space
    # my $lastSrc = $#{$srcids}+1;
    # my $lastTrg = $#{$trgids}+1;
    # push( @$output, join(' ',$lastSrc,$lastTrg,0) );

    foreach (@$output) {
        chomp;

        ## skip lines that do not start with a digit
        next if ( !/^[0-9]/ );

        ## split the line
        my ( $sid, $tid, $score ) = split(/\s+/);

        ## add links
	if ($prevScore < $self->{scorethr} ){
	    $self->{NrSkippedLinks}++;
	    $self->{NrSkippedSrcSents}+=$sid-$prevSrc+1;
	    $self->{NrSkippedTrgSents}+=$tid-$prevTrg+1;
	}
	else{
	    my @srcids = ();
	    if ($sid > $prevSrc){
		foreach ( $prevSrc .. $sid - 1 ) {
		    next if ( $$srcids[$_] eq 'p' );
		    push( @srcids, $$srcids[$_] );
		}
	    }
	    my @trgids = ();
	    if ($tid > $prevTrg){
		foreach ( $prevTrg .. $tid - 1 ) {
		    next if ( $$trgids[$_] eq 'p' );
		    push( @trgids, $$trgids[$_] );
		}
	    }
	    if ( (! $self->{maxsrc} || @srcids <= $self->{maxsrc}) &&
		 (! $self->{maxtrg} || @trgids <= $self->{maxtrg}) ){
		if (@srcids || @trgids){
		    my $idx = @{$links};
		    $links->[$idx]->{src} = [];
		    $links->[$idx]->{trg} = [];
		    push( @{ $links->[$idx]->{src} }, @srcids );
		    push( @{ $links->[$idx]->{trg} }, @trgids );
		    $links->[$idx]->{score} = $prevScore;
		}
	    }
	    else{
		$self->{NrSkippedLinks}++;
		$self->{NrSkippedSrcSents}+=scalar @srcids;
		$self->{NrSkippedTrgSents}+=scalar @trgids;
	    }
	}
        $prevScore = $score;
        $totalScore += $score;
        $prevSrc   = $sid;
        $prevTrg   = $tid;
    }

    if ($#{$output}){
        return $totalScore/$#{$output};
    }

    return 0;
    # return $prevScore;
}


=head2 C<_resource2hunalign>

Create temporary files for running the aligner.

=cut

sub _resource2hunalign {
    my $self = shift;
    my ( $resource, $ids, $langs ) = @_;

    my ( $fh, $tmpfile ) = tempfile(
        'align_XXXXXXXX',
        DIR    => $ENV{UPLOADDIR},
        UNLINK => 1
    );
    binmode( $fh, ':encoding(utf8)' );

    my $reader;
    unless ( $reader = new LetsMT::Export::Reader( $resource, 'xml' ) ) {
        get_logger(__PACKAGE__)->error("cannot read $resource");
    }

    my $before = {};
    $reader->open($resource);
    while ( my $data = $reader->read($before, undef, $langs) ) {
        foreach my $l ( keys %{$data} ) {   # this should be only one language

            ## check if there is a paragraph break before the first sent
            if ( ref( $$before{$l} ) eq 'HASH' ) {
                if ( exists $$before{$l}{p} ) {
                    push( @{$ids}, 'p' );
                    print $fh "<p>\n";
                }
            }
            if ( ref( $$before{$l} ) eq 'ARRAY' ) {
		if ( grep( $$_[0] eq 'p' ,@{$$before{$l}}) ){
                    push( @{$ids}, 'p' );
                    print $fh "<p>\n";
		}
	    }

            foreach my $i ( keys %{ $$data{$l} } ) {
                push( @{$ids}, $i );
                print $fh $$data{$l}{$i} . "\n";
            }
        }
    }
    close $fh;
    return $tmpfile;
}


package LetsMT::Align::Hunalign::Cautious;

use parent 'LetsMT::Align::Hunalign';

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
