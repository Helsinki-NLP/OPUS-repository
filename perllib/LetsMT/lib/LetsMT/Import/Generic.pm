package LetsMT::Import::Generic;

=head1 NAME

LetsMT::Import::Generic - generic import handler

=cut

use strict;
use Data::Dumper;

use LetsMT;
use LetsMT::Export::Reader;
use LetsMT::Import::XCESWriter;
use LetsMT::WebService;
use LetsMT::Lang::Detect;

use LetsMT::DataProcessing::Normalizer::No;
use LetsMT::DataProcessing::Normalizer::DOS;
use LetsMT::DataProcessing::Normalizer::Chain;
use LetsMT::DataProcessing::Normalizer::Whitespace;
use LetsMT::DataProcessing::Normalizer::SeparateHeader;
use LetsMT::DataProcessing::Normalizer::Ligatures;
use LetsMT::DataProcessing::Splitter;

# default normalizer for text import

our $DEFAULT_NORMALIZER = new LetsMT::DataProcessing::Normalizer::Chain(
    new LetsMT::DataProcessing::Normalizer::Whitespace,
    new LetsMT::DataProcessing::Normalizer::SeparateHeader,
    new LetsMT::DataProcessing::Normalizer::Ligatures
);

# our $DEFAULT_NORMALIZER = new LetsMT::DataProcessing::Normalizer::Whitespace;
# our $DEFAULT_NORMALIZER = new LetsMT::DataProcessing::Normalizer::DOS;

our $DEFAULT_SPLITTER = $LetsMT::IMPORT_SPLITTER;


=head1 CONSTRUCTOR

=cut

sub new {
    my $class = shift;
    my %self  = @_;
    bless \%self, $class;
    return \%self;
}


=head1 METHODS

=head2 C<initialize>

Initialize class instance: Make appropriate data pre-processing tools to the object instance.

=cut

sub initialize{
    my $self = shift;

    if ($self->{splitter}) {
        unless ( ref $self->{splitter} ) {
            $self->{splitter} = new LetsMT::DataProcessing::Splitter(
                method => $self->{splitter},
                lang   => $self->{lang}
            );
        }
    }

    if ($self->{tokenizer}) {
        unless ( ref $self->{tokenizer} ) {
            $self->{tokenizer} = new LetsMT::DataProcessing::Tokenizer(
                method => $self->{tokenizer},
                lang   => $self->{lang}
            );
        }
    }

    if ($self->{normalizer}) {
        unless ( ref $self->{normalizer} ) {
            $self->{normalizer} = new LetsMT::DataProcessing::Normalizer(
                type => $self->{normalizer}
            );
        }
    }
}



=head2 C<set_parameter(%ParameterHash)>

Set/change importer parameters.

=cut


sub set_parameter{
    my $self = shift;
    my %para = @_;
    foreach (keys %para) {
        $self->{$_} = $para{$_};
    }
    $self->initialize();
}



=head2 C<validate>

Validation fails in this generic class.

=cut

sub validate {
    my $self = shift;
    my ($resource) = @_;

    return [
        [   $resource,
            import_log => "No validation implemented for " . ref($self)
        ]
    ];
}


=head2 C<convert>

=cut

sub convert {
    my $self = shift;
    my ( $resource, $importer, $meta_resource ) = @_;

    my $type_pattern = $self->{type_pattern} || $self->{type};
    my $new_resource = $resource->convert_type( $type_pattern, 'xml' );

    # shift the 'uploads' path to local_dir
    $new_resource->shift_path_to_local();

    # create text processer tools
    # - default splitter = Lingua::Sentence with resource-specific language

    my $normalizer = $importer->{normalizer} || $DEFAULT_NORMALIZER;
    # my $lang     = $importer->{lang}       || $resource->language();

    ## NEW always use the importer language if it is set and not 'xx'
    ## --> ignore resource language and skip language detection
    ## --> TODO: should we do language detection to verify this?
    ##     (not really necessssary because we detect language for each sentence later anyway)

    my $lang = $importer->{lang} || $resource->language();

    ## run language detection if necessary
    ## (if no lang is set OR it is xx OR we always trust langid)

    if ( $self->{trust_langid} ne 'off' || ! $lang || $lang eq 'xx' ){
	my @detected = &detect_language($resource);
	if ( @detected && $detected[0] ne 'unknown' ){
	    $lang = $detected[0] unless (grep($_ eq $lang,@detected));
	}
    }
    $lang = 'xx' unless ($lang);

    # make sure the subdir is set correctly
    $new_resource->language($lang);

    my $splitter = $importer->{splitter} || new LetsMT::DataProcessing::Splitter(
        method => $DEFAULT_SPLITTER,
        lang   => $lang,
    );

    # let's see if we can find a reader class ...
    my $reader = new LetsMT::Export::Reader(
        format     => $self->{type},
        tokenizer  => $importer->{tokenizer},
        normalizer => $normalizer,
        splitter   => $splitter,
        lang       => $lang,
    );

    # ... or give up
    return undef unless ($reader);

    my $writer = new LetsMT::Import::XCESWriter(
        tokenizer => $importer->{tokenizer}
    );

    my $count;
    my $before = {};
    my $after  = {};

    $reader->open($resource);
    $writer->open($new_resource);

    while ( my $ap = $reader->read( $before, $after ) ) {
        $writer->write( $ap, $before, $after );
        $count++;
        ## report import progress in metadata
        if ( defined $meta_resource ) {
            unless ( $count % 1000 ) {
                &LetsMT::WebService::post_meta( $meta_resource,
                    'import_progress' => $count );
            }
        }
    }
    $reader->close;
    $writer->close;

    if ( defined $meta_resource ) {
        LetsMT::WebService::del_meta( $meta_resource, 'import_progress' );
    }

    # if there is at least one record --> no warning
    if ($count) {
        return $writer->get_resources;
    }

    # nothing read --> add a warning that the resource seems to be empty
    return ( $writer->get_resources, [], [], 'empty resource' );
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
