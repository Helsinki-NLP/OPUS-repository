package LetsMT::Export::Writer;

=head1 NAME

LetsMT::Export::Writer

=head1 DESCRIPTION

Resource-writer objects.

=cut

use strict;

use LetsMT::Export::Writer::Text;
use LetsMT::Export::Writer::XML;
use LetsMT::Export::Writer::TMX;
use LetsMT::Export::Writer::Moses;

use LetsMT::Import::XCESWriter;

=head2 Implemented data formats

=over

=item align - XCES

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

our %WRITER = (
    txt        => 'LetsMT::Export::Writer::Text',
    xml        => 'LetsMT::Export::Writer::XML',
    tmx        => 'LetsMT::Export::Writer::TMX',
    tmx_unique => 'LetsMT::Export::Writer::TMX::Unique',
    moses      => 'LetsMT::Export::Writer::Moses',
    align      => 'LetsMT::Export::Writer::XCES',
    xces       => 'LetsMT::Import::XCESWriter'
);

$WRITER{text}   = $WRITER{txt};
$WRITER{letsmt} = $WRITER{ces};

=head1 METHODS

=head2 Constructor

 $writer = new LetsMT::Export::Writer ($resource, $format)

Returns an appropriate writer object for a given resource $resource.
The data format $format is optional. The constructor tries to infer
the data from the resource object if $format is not specified 
(see L<LetsMT::Resource>::type)

=cut

sub new {
    my $class = shift;

    my $resource = shift;
    my $format = shift || $resource->type;
    return $WRITER{$format}->new(
        resource => $resource,
        format   => $format,
        @_
    );
}


=head2 C<get_resource>

 @resources = $writer->get_resource()

Returns a list of resources created while writing ....

=cut

sub get_resources {
    my $self = shift;

    if ( ref( $self->{RESOURCES} ) eq 'ARRAY' ) {
        return @{ $self->{RESOURCES} };
    }
    return ();
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
