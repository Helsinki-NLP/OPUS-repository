package LetsMT::Import::XLIFF;

=head1 NAME

LetsMT::Import::XLIFF - import handler for XLIFF files

=head1 DESCRIPTION

XLIFF: the XML Localization Interchange File Format.

=cut

use strict;

use Data::Dumper;
use Log::Log4perl qw(get_logger :levels);

use LetsMT;
use LetsMT::Tools;
use LetsMT::Tools::XML qw/:all/;
use LetsMT::WebService;
use LetsMT::Import::XLIFFReader;
use LetsMT::Import::XCESWriter;

use parent 'LetsMT::Import::Generic';


# C<$TMX_DTD>
#
# Path to the current XML Schema for XLIFF. Used for validating.

my $XLIFF_XS  = &File::ShareDir::dist_dir('LetsMT') . '/xs/xliff.xsd';
my $XLIFF_DTD = &File::ShareDir::dist_dir('LetsMT') . '/dtd/xliff.dtd';


=head1 CONSTRUCTOR

=cut

sub new {
    my $class = shift;
    my %self  = @_;
    bless \%self, $class;
    return \%self;
}


=head1 METHODS

=head2 C<validate>

Validate that C<$resource> represents a local XLIFF file
(uses C<Resource::local_path> to locate the file to validate).

Returns a reference to a list of error resources, warning resources and a log message.

=cut

sub validate {
    my $self = shift;
    my ($resource) = @_;

    my $encoding = &LetsMT::Tools::get_bom_encoding( $resource->local_path );
    unless ( $encoding =~ /utf/i || -T $resource->local_path ) {
        return [
            [ $resource, import_log => "failed to validate as text" ]
        ];
    }

    my @err_resources;
    my @log = ();

    ## TODO: we skip the schema-based validation
    ##       this seems to be very slow and possibly unreliable

    ## check whether the validates as XLIFF
    # push @err_resources, &LetsMT::Tools::validate_xs( $resource, $XLIFF_XS );
    # return [] if ( scalar @err_resources == 0 );

    ## check whether the file validates as XLIFF (assuming we have a DOCTYPE)
    push @err_resources, &validate_xml($resource);
    return [] if ( scalar @err_resources == 0 );

    ## check whether the file  validates as XLIFF
    my @err = &validate_dtd( $resource, $XLIFF_DTD );
    push( @err_resources, @err );
    return ( [], \@err_resources ) unless ( scalar @err );

    # add log message
    push( @log, "DTD validation failed" );

    ## check whether the file is at least valid standalone XML
    my @err = &validate_standalone_xml($resource);
    ## skip storing the error resources this time
    ## because we still try to tidy up the XML below
    # push (@err_resources, @err);
    return ( [], \@err_resources, join( ',', @log ) ) unless ( scalar @err );

    # add log message
    push( @log, "XML validation failed" );

    ## try to tidy up ... and validate XML again
    my @err = &tidy_xml($resource);
    push( @err_resources, @err );
    unless ( scalar @err ) {
        my @err = &validate_standalone_xml($resource);
        push( @err_resources, @err );
        return ( [], \@err_resources, join( ',', @log ) )
            unless ( scalar @err );
    }

    # add log message
    push( @log, "tidy-up failed" );

    ## neither valid XLIFF nor valid XML --> fail!
    push @err_resources, [$resource];
    return ( \@err_resources, [], join( ',', @log ) );
}


=head2 C<convert>

Convert the supplied resource from XLIFF to XCES.

=cut

sub convert {
    my $self = shift;
    my ( $resource, $importer, $meta_resource ) = @_;

    my $new_resource = $resource->convert_type( '(?:xliff|xlf)', 'xml' );
    my $lang = $importer->{lang} || $resource->language();

    # shift the 'uploads' path to local_dir
    $new_resource->shift_path_to_local();

    my $reader = new LetsMT::Import::XLIFFReader(
        lang       => $lang,
        tokenizer  => $importer->{tokenizer},
        normalizer => $importer->{normalizer}
    );
    my $writer = new LetsMT::Import::XCESWriter(
        lang      => $lang,
        tokenizer => $importer->{tokenizer}
    );

    my $count;

    $reader->open($resource);
    $writer->open($new_resource);
    while ( my $ap = $reader->read ) {
        $writer->write($ap);
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
        &LetsMT::WebService::del_meta( $meta_resource, 'import_progress' );
    }

    # if there is at least one record --> no warning
    if ($count) {
        return $writer->get_resources;
    }

    # nothing read --> add a warning that the resource seems to be empty
    return ( $writer->get_resources, [], [], "empty resource" );
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