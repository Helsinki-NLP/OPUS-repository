package LetsMT::Export;

=head1 NAME

LetsMT::Export - family of modules for exporting data

=head1 DESCRIPTION

Export resources from the repository into various formats.

This parent class is rarely called directly.

=cut

use strict;

use File::Temp 'tempdir';

use LetsMT;
use LetsMT::Resource;
use LetsMT::WebService;
use LetsMT::Tools; # needed?

use LetsMT::Export::Reader;
use LetsMT::Export::Writer;

=head1 CONSTRUCTOR

 $exporter = new LetsMT::Export ( -verbose => 1, local_root => '...' )

Construct a new export object.

=cut

sub new {
    my $class = shift;
    my %self  = @_;

    my $tmpdir = $ENV{LETSMT_TMP} || '/tmp';
    $self{local_root} = tempdir(
        'export_XXXXXXXX',
        DIR     => $tmpdir,
        CLEANUP => 1,
    ) unless ( defined $self{local_root} );

    $self{COUNT} = 0;
    $| = 1 if ( $self{-verbose} );    # always flush STDOUT in verbose mode

    bless \%self, $class;
    return \%self;
}


=head1 CLASS METHODS

=head2 Filter settings

With two input parameters C<$filter> and C<$value>, set a filter property.
With one input C<$filter>, read the filter's respective setting.

=head3 C<max>

 $exporter->max ($filter, $count)
 $count = $exporter->max ($filter)

Read at most C<$count> data records.

=cut

sub max {
    return defined( $_[1] )
        ? $_[0]->{MAX}  = $_[1]
        : $_[0]->{MAX};
}


=head3 C<skip>

 $skips = $exporter->skip ($filter)
 $exporter->skip ($filter, $skips)

Skip C<$skips> data records.

=cut

sub skip {
    return defined( $_[1] ) 
        ? $_[0]->{SKIP} = $_[1]
        : $_[0]->{SKIP};
}


=head3 C<link_type>

 $exporter->link_type ($filter, $type)
 $type = $exporter->link_type ($filter)

Return only sentence alignments of a certain type C<$filter>.

The C<link_type> filter is only useful for parallel corpora.
The link type (C<$type>) is a simple string, for example, '1:1' to require one-to-one links.

=cut

sub link_type {
    return defined( $_[1] )
        ? $_[0]->{LINK_TYPE} = $_[1]
        : $_[0]->{LINK_TYPE};
}


=head2 C<reset>

 $exporter->reset ($filter)

Reset exporter filters and counters.

=cut

sub reset {
    $_[0]->{COUNT} = 0;
    delete $_[0]->{MAX};
    delete $_[0]->{SKIP};
    delete $_[0]->{LINK_TYPE};
}


=head1 INSTANCE METHODS

=head2 C<export_resource>

 $exporter->export_resource($FromResource,$ToResource,$FromFormat,$ToFormat)

Reads data from $FromResource and writes them to $ToResource.
$FromFormat and $ToFormat are optional and may be infered from the
path of the given resources (see L<LetsMT::Resource>::type).

C<$FromResource>, C<$ToResource> .. LetsMTResource objects

C<$FromType>, C<$ToType> .. strings

See L<LetsMT::Export::Reader> and L<LetsMT::Export::Writer>
for supported resource formats.

Returns a list of resources (LetsMT::Resource objects) created while exporting.

=cut

sub export_resource {
    my $self         = shift;
    my $FromResource = shift || die "need a resource to read from";
    my $ToResource   = shift || die "need a resource to write to";
    my $FromFormat   = shift;
    my $ToFormat     = shift;

    my $writer = $self->open_writer( $ToResource, $ToFormat );
    $self->export( $writer, $FromResource, $FromFormat );

    # list of resources created
    my @resources = $writer->get_resources;
    @resources = ($ToResource) if ( !@resources );
    return @resources;
}

# open is an alias for open_writer
sub open {
    my $self = shift;
    return $self->open_writer(@_);
}


=head2 C<open_reader>

=cut

sub open_reader {
    my $self     = shift;
    my $resource = shift || die "need a resource to read from";
    my $format   = shift;
    my %opts     = @_;

    # set the local directory if not specified
    # use slot-name and user-name to create a unique directory
    # in the local exporter data directory
    unless ( $resource->local_dir ) {
        $resource->local_dir(
            join( '/',
                ( $self->{local_root}, $resource->slot, $resource->user ) )
        );
    }

    my $reader = new LetsMT::Export::Reader( $resource, $format, %opts )
        || die "cannot find appropriate reader for $resource!\n";
    $reader->open( $resource, -link_type => $self->{LINK_TYPE} );
    return $reader;
}


=head2 C<open_writer> | C<open>

=cut

sub open_writer {
    my $self     = shift;
    my $resource = shift || die "need a resource to write to";
    my $format   = shift;

    my $writer = new LetsMT::Export::Writer( $resource, $format )
        || die "cannot find appropriate writer for $resource!\n";
    $writer->open($resource);
    return $writer;
}


=head2 C<export>

Export (read) a given resource and write with the given writer.

=cut

sub export {
    my $self         = shift;
    my $writer       = shift;
    my $FromResource = shift || die "need a resource to read from";
    my $FromFormat   = shift;
    my %ReaderOpts   = @_;

    my $reader = $self->open_reader( $FromResource, $FromFormat, %ReaderOpts );
    die "cannot open reader for $FromResource!" unless ( defined $reader );

    #----------------------------------------------------------------------
    # finally: read through the resource

    while ( my $data = $reader->read() ) {

        ## skip a certain number of data entries
        if ( $self->{SKIP} ) {
            $self->{SKIP}--;
            next;
        }

        if ( $writer->write($data) ) {
            $$self{COUNT}++;

            # stop reading if we have reached a given maximum
            if ( defined $self->{MAX} ) {
                $self->{MAX}--;
                last if ( !$self->{MAX} );
            }

            # print progress
            if ( $self->{-verbose} ) {
                print '.'               if ( !( $$self{COUNT} % 10000 ) );
                print "$$self{COUNT}\n" if ( !( $$self{COUNT} % 500000 ) );
            }
        }
    }

    # end of read/write loop
    #----------------------------------------------------------------------

    $reader->close();

    # list of resources created
    my @resources = $writer->get_resources;
    return @resources;
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
