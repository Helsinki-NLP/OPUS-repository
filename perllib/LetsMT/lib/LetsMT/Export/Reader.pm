package LetsMT::Export::Reader;

=head1 NAME

LetsMT::Export::Reader - reader objects for various data formats

=head1 DESCRIPTION

Reader objects for various data formats.

=cut

use strict;

use LetsMT::Resource;
use LetsMT::WebService;
use LetsMT::Tools;

use LetsMT::Export::Reader::Corpus;
use LetsMT::Export::Reader::XML;
use LetsMT::Export::Reader::XCES;
use LetsMT::Export::Reader::Converter;

use LetsMT::Import::TextReader;
use LetsMT::Import::SRTReader;
use LetsMT::Import::TMXReader;
use LetsMT::Import::XLIFFReader;

=head2 Implemented data formats

=over

=item doc   - Word DOC

=item mono  - Monolingual corpus

=item moses - Moses

=item para  - Parallel corpus

=item pdf   - PDF

=item srt   - SRT

=item text  - Plain text

=item tmx   - TMX

=item xces  - XCES

=item xliff - XLIFF

=item xml   - XML

=back

=cut

our %READER = (
    xml         => 'LetsMT::Export::Reader::XML',
    xces        => 'LetsMT::Export::Reader::XCES',
    parallel    => 'LetsMT::Export::Reader::Corpus',
    monolingual => 'LetsMT::Export::Reader::Corpus',
    text        => 'LetsMT::Import::TextReader',
    srt         => 'LetsMT::Import::SRTReader',
    tmx         => 'LetsMT::Import::TMXReader',
    xliff       => 'LetsMT::Import::XLIFFReader',
    moses       => 'LetsMT::Import::MosesReader'
);

# format aliases

$READER{para} = $READER{parallel};
$READER{mono} = $READER{monolingual};
$READER{txt}  = $READER{text};


=head1 CONSTRUCTOR / FACTORY METHOD

 $reader = new LetsMT::Export::Reader ($resource, $format)

Return an appropriate reader object for a given resource C<$resource>.

The data format C<$format> is optional.
If it is not specified,
the constructor tries to infer the data from the resource object
(see L<LetsMT::Resource|LetsMT::Resource>::type)

=cut

sub new {
    my $class = shift;

    my $resource = shift;
    my $format = shift || $resource->type();

    # either get the format-specific reader
    # or try to convert via XML using the Converter module
    return exists $READER{$format}
        ? $READER{$format}->new(
                resource => $resource,
                format   => $format,
                @_ )
        : new LetsMT::Export::Reader::Converter(
                resource => $resource,
                format   => $format,
                @_ );
}


=head1 CLASS METHOD

=head2 C<reader>

 LetsMT::Export::Reader::reader ($format)

Return appropriate reader for a given format.

=cut

sub reader {
    exists $READER{ $_[0] } ? $READER{ $_[0] } : undef;
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