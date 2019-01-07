package LetsMT::Import::ApacheTika;

=head1 NAME

LetsMT::Import::ApacheTika - generic import handler for documents handled by Apache Tika Server

=head1 DESCRIPTION

This module uses the Apache tool L<Tika|http://tika.apache.org/>
to validate and extract text from various documents.

=cut

use strict;
use parent 'LetsMT::Import::Generic';

use LetsMT;
use LetsMT::Tools;
use LetsMT::Repository::Err;
use LetsMT::WebService;

use Apache::Tika;
use IPC::Run qw(run);
use File::Path;
use Log::Log4perl qw(get_logger :levels);

my $TIKA = Apache::Tika->new();


=head1 CONSTRUCTOR

=cut

sub new {
    my $class = shift;
    my %self  = @_;

    ## could also have rawxml here (use rmeta function to get XML output from TIKA)
    $self{intermediate_format} = 'txt' unless ($self{intermediate_format});

    bless \%self, $class;
    return \%self;
}


=head1 METHODS

=head2 C<validate>

 $handler->validate ($resource)

Validates that C<$resource> is a valid doc format.

=cut

sub validate {
    my $self = shift;
    my ($resource) = @_;

    my $logger = get_logger(__PACKAGE__);

    # document type
    my $type = $self->{type} || $resource->type();

    ## don't redo validation
    if (exists $resource->{apache_tika_validated}){
	if ($resource->{apache_tika_validated}){
	    return ( [] , [[$resource,'detected_stream' => $type]] );
	}
	else{
	    return [ [ $resource, import_log => "failed to delect stream type" ] ];
	}
    }

    # read content and detect type with TIKA
    my $content  = $self->_read_raw_file($resource->local_path);
    my $detected = $TIKA->detect_stream($content);

    if ($detected){
	## a bit of ad-hoc changes to mime-types
	$detected-~s/text\/plain/txt/;
	$detected=~s/^[^\/]+\///;
	$resource->type($detected);
	$resource->{apache_tika_validated} = 1;
	return ( [] , [[$resource,'detected_stream' => $detected]] );
    }

    ## something went wrong
    $logger->warn("failed to detect stream type!");
    $resource->{apache_tika_validated} = 0;
    return [
        [ $resource, import_log => "failed to delect stream type" ]
    ];
}


=head2 C<convert>

 $handler->convert ($resource, $importer)

Convert C<$resource> to text and import the resulting text file.

=cut

sub convert {
    my $self = shift;
    my ( $resource, $importer, $meta_resource ) = @_;

    # Get requested resource if necessary
    if ( ( ! -e $resource->local_path ) || $self->{-always_fetch} ) {
        return 0 unless ( LetsMT::WebService::get_resource($resource) );
    }

    my $logger = get_logger(__PACKAGE__);
    $logger->debug('trying to convert with Apache Tika');

    # document type
    my $type = $self->{type} || $resource->type();

    # read content and parse with TIKA
    my $RawContent    = $self->_read_raw_file($resource->local_path);
    my $ParsedContent;

    ## check whether we want rawxml or text from TIKA
    ## NOTE: extracting meta data seems to be very slow!
    if ( $self->{intermediate_format} eq 'rawxml' ){
	my $parsed = $TIKA->rmeta($RawContent);
	if (ref($parsed) eq 'ARRAY'){
	    if (ref($$parsed[0]) eq 'HASH'){
		my $ParsedContent = $$parsed[0]{'X-TIKA:content'};
	    }
	}
    }
    else {
	$ParsedContent = $TIKA->tika($RawContent);
    }

    if ($ParsedContent){

	## create the intermediate resource
	my $type_pattern = $self->{type_pattern} || $type;
	my $tmp_resource = $resource->convert_type( $type_pattern, $self->{intermediate_format} );
	File::Path::make_path( $tmp_resource->path_down->local_path );

	open F,'>',$tmp_resource->local_path;
	binmode(F,":utf8");
	print F $ParsedContent;
	close F;

	## add pre-processing tools to the importer if necessary
	foreach ('normalizer', 'splitter', 'tokenizer') {
	    unless ( defined $importer->{$_} ) {
		$importer->{$_} = $self->{$_} if (defined $self->{$_});
	    }
	}

	## convert text to XML with sentence markup
	return $importer->convert_resource( $tmp_resource, $meta_resource );
    }
    return [];
}



sub _read_raw_file{
    my $self =shift;
    my $file = shift;
    open my $fh, '<:raw', $file;
    my $content = do { local $/; <$fh> };
    close $fh;
    return $content;
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
