package LetsMT::Import::XCESWriter;

=head1 NAME

LetsMT::Import::XCESWriter - Write files in the internal XCES format

=cut

use strict;

use Data::Dumper;
use File::Path;
use File::Basename;

use LetsMT::DataProcessing::Tokenizer::No;
use LetsMT::DataProcessing::Normalizer::Chain;
use LetsMT::DataProcessing::Normalizer::Moses;
use LetsMT::DataProcessing::Normalizer::Whitespace;
use LetsMT::Tools;

use LetsMT::Export::Writer::XCES;
use LetsMT::Export::Writer::XML;

=head1 CLASS VARIABLE (public)

=head2 C<$DEFAULT_NORMALIZER>

Default text normalizer to be applied before writing sentences to XML.
This will remove initial/trailing/duplicated whitespaces
and also all special characters that may break Moses.

=cut

# TODO: Is this good to always have these normalizers as default?
# could be that we do not always want to normalize texts when converting ....

our $DEFAULT_NORMALIZER = new LetsMT::DataProcessing::Normalizer::Chain(
    new LetsMT::DataProcessing::Normalizer::Moses,
    new LetsMT::DataProcessing::Normalizer::Whitespace
);


=head2 CONSTRUCTOR

=cut

sub new {
    my $class = shift;
    my %self  = @_;
    $self{tokenizer} = $LetsMT::Import::DEFAULT_TOKENIZER
        unless ( defined $self{tokenizer} );
    $self{normalizer} = $DEFAULT_NORMALIZER
        unless ( defined $self{normalizer} );

    # used for printing additional markup
    # TODO: should probably move to use Export::Writer::XML for
    #       generating all xml files ....
    $self{xml_writer} = new LetsMT::Export::Writer::XML;

    bless \%self, $class;
    return \%self;
}


=head1 METHODS

=head2 C<open>

 $writer->open ($resource, $encoding)

Open a resource for writing.
If C<$encoding> is left undefined,
whatever is defined as the default writing encoding in C<LetsMT::Tools> will be used.

=cut

sub open {
    my $self     = shift;
    my $resource = shift || $self->{resource};
    my $encoding = shift || $self->{encoding};

    $self->{resource} = $resource;    # make sure it's really set
    $self->{encoding} = $encoding;
    $self->{lid}      = 1;
    return 1;                         # so far, so good ....
}


=head2 write

 $writer->write ($tu)

Write translation unit C<$tu> to the open resource.

=cut

sub write {
    my $self      = shift;
    my $sent_pair = shift;

    my $before = shift || {};    # optional data from before this TU
    my $after  = shift || {};    # optional data from after this TU

    # Exctract the invloved language codes in alphabetic order.
    my @langs = sort keys %$sent_pair;

    # Loop over all language codes.
    foreach my $lang (@langs) {

        # Make sure there is a relevant monolingual file to write to.
        my $writer = $self->get_xml_writer($lang);

        # normalize data
        my %data = ();
        foreach my $sid ( keys %{ $sent_pair->{$lang} } ) {
            $data{$lang}{$sid}
                = $self->{tokenizer}->detokenize( $sent_pair->{$lang}{$sid} );
            $self->{normalizer}->normalize_no_copy( $data{$lang}{$sid} );
            $self->{resources}{$lang}{meta}{size}++;
        }

        # finally print them!
        $writer->write( \%data, $before, $after );

    }

    # Loop over all language code pairs.
    while ( my $src = shift @langs ) {
        foreach my $trg (@langs) {

            # Make sure the is a relevant alignment file for the
            # language code pair.
            my $writer = $self->get_xces_writer( $src, $trg );

            my @src_ids = sort keys %{ $sent_pair->{$src} };
            my @trg_ids = sort keys %{ $sent_pair->{$trg} };

            $writer->write( \@src_ids, \@trg_ids );

            # Update size. TODO: it looks ugly to mess around with internals
            $self->{resources}{ $src . '-' . $trg }{meta}{size}++;
        }
    }
}


=head2 C<get_xml_writer>

 $writer->get_xml_writer ($lang)

Return language-specific XML writer object (create if necessary).

=cut

sub get_xml_writer {
    my $self = shift;
    my $id   = shift;

    unless ( defined $self->{resources}{$id} ) {
        # clone the base resource and set a new language ID
        # (which also changes the path!!!)
        my $new_resource = $self->{resource}->clone;
        $new_resource->language($id);

        my $writer = new LetsMT::Export::Writer::XML;
        $writer->open($new_resource);

        $self->{resources}{$id} = {
            resource => $new_resource,
            writer   => $writer,
            meta     => {
                size            => 0,
                'resource-type' => 'corpusfile',
                language        => $id
            }
        };
    }

    return $self->{resources}{$id}{writer};
}


=head2 C<get_xces_writer>

 $writer->get_xces_writer ($src_lang, $trg_lang)

Return language-pair-specific XCES alignment writer object (create if necessary).

=cut

sub get_xces_writer {
    my $self = shift;
    my $src  = shift;
    my $trg  = shift;

    my $id = $src . '-' . $trg;

    unless ( defined $self->{resources}{$id} ) {

        # clone the base resource and set a new language ID
        # (which also changes the path!!!)
        my $new_resource = $self->{resource}->clone;
        $new_resource->language($id);

        my $writer = new LetsMT::Export::Writer::XCES;
        $writer->open($new_resource);

        my $from_doc = $self->{resources}{$src}{resource}->path;
        my $to_doc   = $self->{resources}{$trg}{resource}->path;

        $self->{resources}{$id} = {
            resource => $new_resource,
            writer   => $writer,
            meta     => {
                size              => 0,
                'resource-type'   => 'sentalign',
                language          => join( ',', ( $src, $trg ) ),
                'source-language' => $src,
                'target-language' => $trg,
                'source-document' => $from_doc,
                'target-document' => $to_doc
            }
        };

        $from_doc =~ s/xml\///i;    # Mutilate paths in favor of
        $to_doc   =~ s/xml\///i;    # future extensions.

        $writer->open_document_pair( $from_doc, $to_doc );

    }
    return $self->{resources}{$id}{writer};
}


=head2 C<close>

=cut

sub close {
    my $self = shift;

    # close all writers
    foreach my $res ( values %{ $self->{resources} } ) {
        $res->{writer}->close();
    }

    # update "aligned_with" field in the metadata
    my %aligned = ();
    foreach my $id ( keys %{ $self->{resources} } ) {
        my @lang = split( /\-/, $id );
        if ($#lang) {
	    if ( exists $$self{resources}{ $lang[1] } ){
		if ( exists $$self{resources}{ $lang[1] }{resource} ){
		    push(
			@{ $aligned{ $lang[0] } },
			$$self{resources}{ $lang[1] }{resource}->path
			);
		}
	    }
	    if ( exists $$self{resources}{ $lang[0] } ){
		if ( exists $$self{resources}{ $lang[0] }{resource} ){
		    push(
			@{ $aligned{ $lang[1] } },
			$$self{resources}{ $lang[0] }{resource}->path
			);
		}
	    }
        }
    }

    # NOTE: this will be *posted* by Import
    # --> old meta data will be overwritten!
    foreach my $id ( keys %aligned ) {
        $$self{resources}{$id}{meta}{aligned_with}
            = join( ',', @{ $aligned{$id} } );
    }

}


=head2 C<get_resources>

Returns a reference to the list of resources that were writte to. The return
value is formatted to be useful to C<LetsMT::Import>.

=cut

sub get_resources {
    my $self = shift;
    return [ values %{ $self->{resources} } ];
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
