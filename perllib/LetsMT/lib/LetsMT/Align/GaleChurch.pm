package LetsMT::Align::GaleChurch;

=head1 NAME

LetsMT::Align::GaleChurch - Sentence-align using the approach by Gale & Church

=head1 DESCRIPTION

Sentence-align two resources using a length-based approach (Gale & Church, 1991/1993).

=cut

use strict;
use parent 'LetsMT::Align';

use Log::Log4perl qw(get_logger :levels);

use LetsMT::Export::Reader;
use LetsMT::Export::Writer;
use LetsMT::Export::Writer::XCES;
use LetsMT::WebService;

# search window (set to 0 to use entire search space)
my $SEARCH_WINDOW = 0;

# PILLOW=1: create a pillow-shaped search space around the diagonal
#  - size = 2*sqrt(DistanceToTextBoundary)
#  - min-size = $SEARCH_WINDOW
my $PILLOW = 0;

# sample mean and variance
my $MEAN = 1;
my $VAR  = 6.8;

# prior link probabilities
my %PRIOR;
$PRIOR{1}{1} = 0.89;
$PRIOR{1}{0} = 0.01 / 2;
$PRIOR{0}{1} = 0.01 / 2;
$PRIOR{2}{1} = 0.089 / 2;
$PRIOR{1}{2} = 0.089 / 2;
$PRIOR{2}{2} = 0.011;

#  $PRIOR{3}{1} = 0.011/2;
#  $PRIOR{1}{3} = 0.011/2;


=head1 CONSTRUCTOR

 $aligner = new LetsMT::Align (method => 'gale', %params)

Possible parameters (%args):

 search_window => <size>

Size of the search window to prune the dynamic programming.
If not set or zero: Do complete search (quadratic in number of sentences).
Default = $SEARCH_WINDOW.

 mean => <value>
 variance => <value>

Mean and variance of the normal distribution used in the length-match costs. Default values: mean=1, variance=6.8 (from original paper)

  prior => \%linktype-priors

Prior probabilities of all accepted link types. %linktype-priors is a two dimensional hash, for example:

 {
   1 => { 1 => 0.8, 2 => 0.1 },
   2 => { 1 => 0.05, 2 => 0.05}
 }

This defines a prior distribution

  1:1 links = 0.9
  1:2 links = 0.1
  2:1 links = 0.05
  2:2 links = 0.05

=cut

sub new {
    my $class = shift;
    my %self  = @_;

    ## save given arguments to save them later in metadata
    %{ $self{args} } = @_;

    ## set some defaults
    $self{prior}         = $self{prior}    || \%PRIOR;
    $self{mean}          = $self{mean}     || $MEAN;
    $self{variance}      = $self{variance} || $VAR;
    $self{search_window} = exists $self{search_window}
        ? $self{search_window}
        : $SEARCH_WINDOW;
    $self{pillow}        = $self{pillow}   || $PILLOW;

    # if the prior parameter is not a hash-ref ....
    # TODO: use Data::Dumper to create the hash from a string
    #       (or fail)
    unless (ref($self{prior}) eq 'HASH'){
        $self{prior} = \%PRIOR;          # set default for now ....
    }

    return bless \%self, $class;
}


=head2 C<align>

 $AlgRes = align ($SrcRes, $TrgRes [, $AlgRes])

Align C<$SrcRes> and C<$TrgRes> with each other and save sentence alignments in C<$AlgRes>.
If no C<$AlgRes> is given: Create a new resource from the information found in C<$SrcRes>, C<$TrgRes>
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

    my ( @SrcIDs, @SrcLen );
    my ( @TrgIDs, @TrgLen );
    my %DetectedLang = ();

    get_sentence_lengths( $SrcResource, \@SrcIDs, \@SrcLen, \%DetectedLang );
    get_sentence_lengths( $TrgResource, \@TrgIDs, \@TrgLen, \%DetectedLang );
    my @links = $self->length_align( \@SrcLen, \@TrgLen, \@SrcIDs, \@TrgIDs );

    $self->write_links($AlgResource, \@links, \%DetectedLang);

    # my $writer = new LetsMT::Export::Writer::XCES();
    # $writer->open($AlgResource);
    # $writer->open_document_pair( $AlgResource->fromDoc, $AlgResource->toDoc );

    # my ($SrcLang,$TrgLang) = $AlgResource->language;
    # %{ $self->{LinkTypes} } = ();
    # $self->{NrLinks} = 0;

    # $self->{SIZE} = 0;
    # foreach my $l (@links) {
    #     $l->{src} = [] unless ( ref( $l->{src} ) eq 'ARRAY' );
    #     $l->{trg} = [] unless ( ref( $l->{trg} ) eq 'ARRAY' );
    #     my $nrSrc = scalar @{ $l->{src} };
    #     my $nrTrg = scalar @{ $l->{trg} };
    #     $self->{LinkTypes}->{"$nrSrc:$nrTrg"}++;
    # 	my $ok = 1;
    # 	foreach $s (@{$l->{src}}){
    # 	    $ok = 0 if ($DetectedLang{$SrcLang}{$s}{lang} && 
    # 			$DetectedLang{$SrcLang}{$s}{lang} ne $SrcLang);
    # 	}
    # 	foreach $t (@{$l->{trg}}){
    # 	    $ok = 0 if ($DetectedLang{$TrgLang}{$t}{lang} && 
    # 			$DetectedLang{$TrgLang}{$t}{lang} ne $TrgLang);
    # 	}
    #     $writer->write( $l->{src}, $l->{trg} ) if ($ok);
    #     $self->{NrLinks}++;
    # }
    # $writer->close();

    # $self->{NrSrcSents} = scalar @SrcIDs;
    # $self->{NrTrgSents} = scalar @TrgIDs;

    # if ( $self->{verbose} ) {
    #     foreach ( keys %{ $self->{LinkTypes} } ) {
    #         print STDERR "type = $_: $self->{LinkTypes}->{$_} times\n";
    #     }
    #     print STDERR "$self->{NrLinks} links\n";
    #     print STDERR "$self->{NrSrcSents} source sentences\n";
    #     print STDERR "$self->{NrTrgSents} target sentences\n";
    #     print STDERR "final alignment cost: $self->{AlignCost}\n";
    #     if ( $self->{NrLinks} ) {
    #         printf STDERR "average cost = %5.2f\n",
    #             $self->{AlignCost} / $self->{NrLinks};
    #     }
    # }

    return $AlgResource;
}


=head2 C<get_sentence_lengths>

Read all sentences from the resource and return sentence IDs and lengths.

=cut

sub get_sentence_lengths {
    my $resource = shift;
    my ( $ids, $len, $lang ) = @_;

    my $reader;
    unless ( $reader = new LetsMT::Export::Reader( $resource, 'xml' ) ) {
        get_logger(__PACKAGE__)->error("cannot read $resource");
    }

    $reader->open($resource);
    while ( my $data = $reader->read( undef, undef, $lang ) ) {
        foreach my $l ( keys %{$data} ) {   # this should be only one language
            foreach my $i ( keys %{ $$data{$l} } ) {
                push( @{$ids}, $i );
                my $length
                    = scalar @{$len}
                    ? $$len[-1] + length( $$data{$l}{$i} )
                    : length( $$data{$l}{$i} );
                push( @{$len}, $length );
            }
        }
    }
    return scalar @{$len};
}


=head2 C<length_align>

=cut

sub length_align {
    my $self = shift;
    my ( $LEN1, $LEN2, $IDS1, $IDS2 ) = @_;

    if ( not @{$LEN1} ) {
        my @LINKS = ();
        $LINKS[0]{src} = [];
        foreach ( 0 .. $#{$LEN2} - 1 ) {
            push( @{ $LINKS[0]{trg} }, $$IDS2[$_] );
        }
        return @LINKS;
    }
    if ( not @{$LEN2} ) {
        my @LINKS = ();
        $LINKS[0]{trg} = [];
        foreach ( 0 .. $#{$LEN1} - 1 ) {
            push( @{ $LINKS[0]{src} }, $$IDS1[$_] );
        }
        return @LINKS;
    }

    my $window = $self->{search_window} || $#{$LEN2};

    # dynamic programming
    my ( @COST, @BACK );
    $COST[0][0] = 0;
    for ( my $i1 = 0; $i1 <= $#{$LEN1}; $i1++ ) {

        # define size of the search window
        my $size = $window;
#        if ($PILLOW) {
        if ($self->{pillow}) {
            my $distance = $i1 > $#{$LEN1} / 2 ? $#{$LEN1} - $i1 : $i1;
            $size += 2 * int( sqrt($distance) + 0.5 );
        }

        my $start = $i1 - $size > 0         ? $i1 - $size : 0;
        my $end   = $i1 + $size < $#{$LEN2} ? $i1 + $size : $#{$LEN2};

        for ( my $i2 = $start; $i2 <= $end; $i2++ ) {
            next if $i1 + $i2 == 0;
            $COST[$i1][$i2] = 1e10;
            foreach my $d1 ( keys %{ $$self{prior} } ) {
                next if $d1 > $i1;
                next if ( !ref( $COST[ $i1 - $d1 ] ) );
                foreach my $d2 ( keys %{ $$self{prior}{$d1} } ) {
                    next if $d2 > $i2;
                    next if ( !defined $COST[ $i1 - $d1 ][ $i2 - $d2 ] );
                    my $cost
                        = $COST[ $i1 - $d1 ][ $i2 - $d2 ]
                        - log( $$self{prior}{$d1}{$d2} ) 
                        + &match(
                        $$LEN1[$i1] - $$LEN1[ $i1 - $d1 ],
                        $$LEN2[$i2] - $$LEN2[ $i2 - $d2 ],
                        $$self{mean}, $$self{variance}
                        );
                    if ( $cost < $COST[$i1][$i2] ) {
                        $COST[$i1][$i2] = $cost;
                        @{ $BACK[$i1][$i2] } = ( $i1 - $d1, $i2 - $d2 );
                    }
                }
            }
        }
    }

    # back tracking
    my %NEXT  = ();
    my @LINKS = ();

    my $i1 = $#{$LEN1};
    my $i2 = $#{$LEN2};

    while ( $i1 > 0 || $i2 > 0 ) {
        @{ $NEXT{ $BACK[$i1][$i2][0] }{ $BACK[$i1][$i2][1] } } = ( $i1, $i2 );
        ( $i1, $i2 ) = ( $BACK[$i1][$i2][0], $BACK[$i1][$i2][1] );
    }
    while ( $i1 < $#{$LEN1} || $i2 < $#{$LEN2} ) {
        push( @LINKS, {} );
        for ( my $i = $i1; $i < $NEXT{$i1}{$i2}[0]; $i++ ) {
            my $sid = $$IDS1[$i];
            push( @{ $LINKS[-1]{src} }, $sid );
        }
        for ( my $i = $i2; $i < $NEXT{$i1}{$i2}[1]; $i++ ) {
            my $sid = $$IDS2[$i];
            push( @{ $LINKS[-1]{trg} }, $sid );
        }
        ( $i1, $i2 ) = @{ $NEXT{$i1}{$i2} };
    }
    $self->{AlignCost} = $COST[$i1][$i2];
    return @LINKS;
}


=head2 C<match>

=cut

sub match {
    my ( $len1, $len2, $mean, $var ) = @_;

    if ( $len1 == 0 && $len2 == 0 ) { return 0; }
    my $avg = ( $len1 + $len2 / $mean ) / 2;
    my $z   = ( $mean * $len1 - $len2 ) / sqrt( $var * $avg );
    if ( $z < 0 ) { $z = -$z; }
    my $pd = 2 * ( 1 - &pnorm($z) );
    if ( $pd > 0 ) { return -log($pd); }
    return 25;
}


=head2 C<pnorm>

=cut

sub pnorm {
    my ($z) = @_;
    my $t = 1 / ( 1 + 0.2316419 * $z );
    return 1 - 0.3989423 * exp( -$z * $z / 2 ) * (
        (   ( ( 1.330274429 * $t - 1.821255978 ) * $t + 1.781477937 ) * $t
                - 0.356563782
        ) * $t + 0.319381530
    ) * $t;
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
