package LetsMT::Import::XML;

=head1 NAME

LetsMT::Import::XML - import handler generic XML filwes

=head1 DESCRIPTION

=cut

use strict;

use parent 'LetsMT::Import::Generic';

use File::ShareDir;
use Log::Log4perl qw(get_logger :levels);

use LetsMT;
use LetsMT::Tools;
use LetsMT::Tools::XML qw/:all/;
use LetsMT::Import::XMLReader;
use LetsMT::Import::XCESWriter;
use LetsMT::WebService;

use LetsMT::Lang::ISO639;
use LetsMT::Lang::Detect;
use LetsMT::DataProcessing::Splitter;



=head1 CONSTRUCTOR

=cut

sub new {
    my $class = shift;
    my %self  = @_;
    $self{type_pattern} = '(?:xml|rawxml)';    # special pattern to convert res
    bless \%self, $class;
    return \%self;
}


=head1 METHODS

=head2 C<validate>

 $valid = $handler->validate ($resource)

Validate that C<$resource> represents a local tmx-file
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
    my $lang = $resource->language();

    my @err_resources;    # collection of error/warning resources
    my @log = ();         # list of log messages

    ## check whether the file is at least valid standalone XML
    my @err = &validate_standalone_xml($resource);

    # XML validation is not OK --> test to tidy up
    if ( scalar @err ) {

	# add log message
	push( @log, "XML validation failed" );

	## try to tidy up ... and validate XML again
	my @err = &tidy_xml($resource);
	push( @err_resources, @err );
	if ( scalar @err ){
	    # add log message
	    push( @log, "tidy-up failed" );
	    push @err_resources, [ $resource ];
	    return ( \@err_resources, [], join(',',@log) );
	}
	else {
	    my @err = &validate_standalone_xml($resource);
	    if ( scalar @err ){
	    	# add log message
		push( @log, "XML validation failed" );
		return ( \@err_resources, [], join(',',@log) );
	    }
	}
    }

    # unless ($lang){
    # 	my @detected = &detect_language($resource);
    # 	unless ( $detected[0] eq 'unknown' ){
    # 	    $resource->language( $detected[0] );
    # 	}
    # }

    return ( [], \@err_resources, join( ',', @log ) )
}


=head2 C<convert>

 $handler->covnert ($resource, $importer)

Convert the supplied resource from C<tmx> to C<xces>.

=cut

sub convert {
    my $self = shift;
    my ( $resource, $importer, $meta_resource, $new_resource ) = @_;

    unless ($new_resource) {
	$new_resource = $resource->convert_type( $self->{type_pattern}, 'xml' );
	# $new_resource = $resource->clone;
	# $new_resource->{path}=~s/\.xml$/_converted\.xml/;
    }

    # shift the 'uploads' path to local_dir
    $new_resource->shift_path_to_local();

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


    ## ugly hack to avoid overwriting the same file
    if ($new_resource->local_path eq $resource->local_path ){
	$new_resource->{path}=~s/\.xml$/_converted\.xml/;
    }

    # # try to detect the language if it is not specified or 'xx'
    # if ((!$lang) || ($lang eq 'xx')){
    #     my @detected = &detect_language($resource);
    #     $lang = shift(@detected) || 'xx';
    # }

    my $splitter = $importer->{splitter} || new LetsMT::DataProcessing::Splitter(
        method => $LetsMT::IMPORT_SPLITTER,
        lang   => $lang,
    );

    my $reader = new LetsMT::Import::XMLReader(
        lang       => $lang,
        tokenizer  => $importer->{tokenizer},
        normalizer => $importer->{normalizer},
	splitter   => $splitter
    );
    my $writer = new LetsMT::Import::XCESWriter(
        lang      => $lang,
        tokenizer => $importer->{tokenizer},
    );

    my $count;

    $reader->open($resource);
    $writer->open($new_resource);

    my $before = {};
    my $after  = {};

    while ( my $ap = $reader->read($before,$after) ) {
        $writer->write($ap,$before,$after);
        $count++;
        ## report import progress in metadata
        if ( defined $meta_resource ) {
            unless ( $count % 1000 ) {
                &LetsMT::WebService::post_meta( $meta_resource,
                    'import_progress' => $count );
            }
        }
    }
    ## TODO: need to write final markup
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
