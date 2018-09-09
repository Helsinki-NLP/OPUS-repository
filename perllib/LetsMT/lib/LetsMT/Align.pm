package LetsMT::Align;

=head1 NAME

LetsMT::Align - family of modules for sentence alignment

=head1 DESCRIPTION

A factory class to return an object instance of a selected alignment module.

=cut

use strict;
use File::Temp 'tempdir';
use File::Path;

use LetsMT::WebService;
use LetsMT::Resource;
use LetsMT::Corpus;

use LetsMT::Align::GaleChurch;
use LetsMT::Align::OneToOne;
use LetsMT::Align::Hunalign;
use LetsMT::Align::Hunalign::Bisent;

use Log::Log4perl qw(get_logger :levels);
use Data::Dumper;
$Data::Dumper::Terse  = 1;
$Data::Dumper::Indent = 0;

=head1 CONSTRUCTOR

 $aligner = new LetsMT::Align (method => 'hunalign|gale|one-to-one|bisent', %params)

Return an object instance of the alignment module that is selected with the 'method' argument.
Available methods:

=over

=item * Hunalign

=item * One-to-one

=item * Gale-Church

=item * Hunalign in 'bisent' mode

=back

Default is the Hunalign sentence aligner.

%params is a hash of additional parameters (specific to the alignment method chosen).

=cut

sub new {
    my $class = shift;
    my %self  = @_;

    if ( $self{method} =~ /(one\-?to\-?one|1to1)/i ) {
        return new LetsMT::Align::OneToOne(@_);
    }
    if ( $self{method} =~ /(length|gale|church)/i ) {
        return new LetsMT::Align::GaleChurch(@_);
    }
    if ( $self{method} =~ /(bisent|cautious)/i ) {
        return new LetsMT::Align::Hunalign::Bisent(@_);
    }
    if ( $self{method} =~ /hun/i ) {
        return new LetsMT::Align::Hunalign(@_);
    }

    # default aligner = hunalign in bisent mode
    return new LetsMT::Align::Hunalign::Bisent(@_);
}


=head1 METHODS

=head2 align_resources

 $AlignRes = $aligner->align_resources($SrcRes, $TrgRes [, $AlignRes])

Align sentences of two given resources ($SrcRes,$TrgRes) in the resource repository.
Returns the resource object ($AlgRes) that stores the sentence alignment.

The $AlignRes argument is optional.
If it is not given, a clone of the $SrcRes is used with the language part of its path replaced
by the language pair (language of $SrcRes + language of $TrgRes, sorted alphabetically)
(see make_align_resource).

=cut

sub align_resources {
    my $self        = shift;
    my $SrcResource = shift;
    my $TrgResource = shift;
    my $AlgResource = shift;

    my $logger = get_logger(__PACKAGE__);

    my $workdir = tempdir(
        'align_XXXXXXXX',
        DIR     => '/tmp',
        CLEANUP => 1
    );

    # use a temp dir for all data files (if not set otherwise)
    $SrcResource->local_dir($workdir) unless(-d $SrcResource->local_dir());
    $TrgResource->local_dir($workdir) unless(-d $TrgResource->local_dir());
    if (ref($AlgResource)){
        $AlgResource->local_dir($workdir) unless(-d $AlgResource->local_dir());
    }

    &LetsMT::WebService::post_meta(
        $SrcResource,
        status => "aligning with $TrgResource"
    );
    LetsMT::WebService::post_meta(
        $TrgResource,
        status => "aligning with $SrcResource"
    );

    #
    # Get resources
    #
    unless ( LetsMT::WebService::get_resource($SrcResource) ) {
        $logger->warn("Unable to fetch $SrcResource");
        LetsMT::WebService::post_meta(
            $SrcResource,
            status => 'failed to fetch'
        );
        return 0;
    }
    my $SrcRevision = $SrcResource->revision();
    unless ( LetsMT::WebService::get_resource($TrgResource) ) {
        $logger->warn("Unable to fetch $TrgResource");
        LetsMT::WebService::post_meta(
            $TrgResource,
            status => 'failed to fetch'
        );
        return 0;
    }
    my $TrgRevision = $TrgResource->revision();

    # swap if needed (language IDs should be sorted)
    if ( $SrcResource->language() gt $TrgResource->language() ) {
        ( $SrcResource, $TrgResource ) = ( $TrgResource, $SrcResource );
    }

    unless ( ref($AlgResource) ) {
        $AlgResource = LetsMT::Align::make_align_resource(
            $SrcResource,
            $TrgResource
        );
    }

    my $start = time();
    if ( $AlgResource = $self->align( $SrcResource, $TrgResource, $AlgResource, @_ ) )
    {
        if ( LetsMT::WebService::put_resource($AlgResource) ) {
            ## put aligner arguments into a string
            my $args = defined $self->{args} ? Dumper( $self->{args} ) : '';
            $args =~ s/^\{//;
            $args =~ s/\}$//;    # remove brackets
            ## get the source & target language
            my ( $SrcLang, $TrgLang ) = $AlgResource->language();

            # (alignment costs and confidence scores depends on aligner)
            my %meta = (
                'size'                 => $self->nr_links(),
                'resource-type'        => 'sentalign',
                'language'             => join( ',', ( $SrcLang, $TrgLang ) ),
                'source-language'      => $SrcLang,
                'target-language'      => $TrgLang,
                'source-document'      => $SrcResource->path,
                'source-revision'      => $SrcRevision,
                'target-document'      => $TrgResource->path,
                'target-revision'      => $TrgRevision,
                'alignment-type'       => 'automatic',
                'aligner'              => ref($self),
                'aligner-arguments'    => $args,
                'nr-source-sents'      => $self->nr_source_sentences(),
                'nr-target-sents'      => $self->nr_target_sentences(),
                'alignment-cost'       => $self->align_cost(),
                'average-link-cost'    => $self->average_align_cost(),
                'alignment-confidence' => $self->align_confidence(),
                'running-time'         => time() - $start
            );

            # statistics of alignment types
            my $LinkTypes = $self->link_types;
            if ( keys %{$LinkTypes} ) {
                foreach ( sort keys %{$LinkTypes} ) {
                    $meta{'link-types'} .= "$_=$$LinkTypes{$_},";
                }
                $meta{'link-types'} =~ s/\,$//;
            }

            # post some meta data
            LetsMT::WebService::post_meta( $AlgResource, %meta );
            LetsMT::WebService::post_meta(
                $SrcResource,
                status => "successfully aligned with $TrgResource"
            );
            LetsMT::WebService::post_meta(
                $TrgResource,
                status => "successfully aligned with $SrcResource"
            );

            # update the list of aligned resources
            LetsMT::WebService::put_meta(
                $SrcResource,
                aligned_with => $TrgResource->path
            );
            LetsMT::WebService::put_meta(
                $TrgResource,
                aligned_with => $SrcResource->path
            );

	    $logger->debug("ALIGN: remove ".$TrgResource->path." from ".$SrcResource->path);
            # finally, remove target from align-candidates
            LetsMT::WebService::del_meta(
                $SrcResource,
                'align-candidates' => $TrgResource->path
            );

            return $AlgResource;
        }
    }
    LetsMT::WebService::post_meta(
        $SrcResource,
        status => "failed to align with $TrgResource"
    );
    LetsMT::WebService::post_meta(
        $TrgResource,
        status => "failed to align with $SrcResource"
    );
    return undef;
}


=head2 make_align_resource

 $AlignRes = $aligner->make_align_resource($SrcRes, $TrgRes)

Create a resource for storing sentence alignment between $SrcRes and $TrgRes.

$AlignRes will be a clone of $SrcRes except for the language part of the path.
The language will be replaced by the language pair taken from the given resources $SrcRes and $TrgRes.

=cut

sub make_align_resource {
    my ( $SrcResource, $TrgResource ) = @_;

    my $resource = $SrcResource->clone;

    my $SrcLang = $SrcResource->language();
    my $TrgLang = $TrgResource->language();

    my $fromDoc = $SrcResource->path();
    my $toDoc = $TrgResource->path();

    # we decided to remove the initial xml/ path to make the aligned doc's
    # relative to the XML home directory
    $fromDoc =~ s/^xml\///;
    $toDoc =~ s/^xml\///;

    # fromDoc and toDoc include revision numbers
    $resource->fromDoc($fromDoc.'@'.$SrcResource->revision());
    $resource->toDoc($toDoc.'@'.$TrgResource->revision());

    $resource->language( $SrcLang . '-' . $TrgLang );

    return $resource;
}


=head2 nr_links

How many links exist in the object?

=cut

sub nr_links {
    return exists $_[0]->{NrLinks} ? $_[0]->{NrLinks} : undef;
}


=head2 nr_source_sentences

How many source sentences are there in the object?

=cut

sub nr_source_sentences {
    return exists $_[0]->{NrSrcSents} ? $_[0]->{NrSrcSents} : undef;
}


=head2 nr_target_sentences 

How many target sentences are there in the object?

=cut

sub nr_target_sentences {
    return exists $_[0]->{NrTrgSents} ? $_[0]->{NrTrgSents} : undef;
}


=head2 link_types

Which are the link types in the object?

=cut

sub link_types {
    return exists $_[0]->{LinkTypes} ? $_[0]->{LinkTypes} : {};
}


=head2 align_cost

What is the total cost of the alignments processed by object?

=cut

sub align_cost {
    return exists $_[0]->{AlignCost} ? $_[0]->{AlignCost} : undef;
}


=head2 average_align_cost

What is the average cost per alignment processed by the object?

=cut

sub average_align_cost {
    if ( exists $_[0]->{AlignCost} ) {
        if ( ( exists $_[0]->{NrLinks} ) && $_[0]->{NrLinks} ) {
            return $_[0]->{AlignCost} / $_[0]->{NrLinks};
        }
    }
    return undef;
}

=head2 average_align_confidence

What is the average cost per alignment processed by the object?

=cut

sub align_confidence {
    return exists $_[0]->{AlignConfidence} ? $_[0]->{AlignConfidence} : undef;
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
