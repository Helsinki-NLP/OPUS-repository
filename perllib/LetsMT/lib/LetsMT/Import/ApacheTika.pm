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
use LetsMT::Align::Documents;

use Apache::Tika;
use IPC::Run qw(run);
use File::Path;
use File::Basename qw/dirname basename/;

## TODO: which module is the safest to use?
##       there is also URI::Encode, ...
# use URL::Encode qw/:all/;
# use URI::Escape::XS qw/uri_escape uri_unescape/;
use URI::Escape::XS;
use utf8;

use Log::Log4perl qw(get_logger :levels);

my $TIKA = Apache::Tika->new();

## restrict size of data to be used for stream type detection
my $TYPE_DETECT_MAX_SIZE = 65536;
# my $TYPE_DETECT_MAX_SIZE = 1048576

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

    # read content and detect type with Apache Tika (max 64k)
    my $content  = $self->_read_raw_file($resource->local_path, $TYPE_DETECT_MAX_SIZE);
    my $detected = $TIKA->detect_stream($content);

    if ($detected){
	## a bit of ad-hoc changes to mime-types
	$detected-~s/text\/plain/txt/;
	$detected=~s/^[^\/]+\///;
	$detected = 'rawxml' if ($detected eq 'xml'); 
	# $resource->{type} = $detected;
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
    # print STDERR "ApacheTika: read raw file ... ";
    my $RawContent    = $self->_read_raw_file($resource->local_path);
    # print STDERR "done\n";
    my $ParsedContent;

    ## extract links between languages
    ## --> site-specific links
    ## --> is there any generic way of doing it?
    my %translations = ();
    if ($resource->type() eq 'html'){
	# print STDERR "ApacheTika: find language links ... ";
	%translations = &extract_language_links($RawContent,$resource->path,$importer->{langlinks});
	# %translations = _extract_language_links($RawContent,$resource->path,'vnk');
	# print STDERR "done\n";
    }

    ## check whether we want rawxml or text from TIKA
    ## NOTE: extracting meta data seems to be very slow!
    if ( $self->{intermediate_format} eq 'rawxml' ){
	# print STDERR "ApacheTika: parse document and return rmeta ... ";
	my $parsed = $TIKA->rmeta($RawContent);
	# print STDERR "done!\n";
	if (ref($parsed) eq 'ARRAY'){
	    if (ref($$parsed[0]) eq 'HASH'){
		$ParsedContent = $$parsed[0]{'X-TIKA:content'};
	    }
	}
    }
    else {
	# print STDERR "ApacheTika: parse document and return text ... ";
	$ParsedContent = $TIKA->tika($RawContent);
	# print STDERR "done!\n";
    }

    if ($ParsedContent){

	## create the intermediate resource
	my $type_pattern = $self->{type_pattern} || $type;
	my $tmp_resource = $resource->convert_type( $type_pattern, $self->{intermediate_format} );

	## NEW: decode URLs! (TODO: is it OK to do that for all resources?)
	## (this breaks with malformed strings)
	# $tmp_resource->path( &url_decode_utf8($tmp_resource->path) );

	## NEW: use URI::Escape::XS
	my $decoded = decodeURIComponent( $tmp_resource->path );
	if (utf8::decode($decoded)){
	    $tmp_resource->path( $decoded );
	}

	File::Path::make_path( $tmp_resource->path_down->local_path );

	# print STDERR "ApacheTika: print converted file content ... ";
	open F,'>',$tmp_resource->local_path;
	binmode(F,":utf8");
	print F $ParsedContent;
	close F;
	# print STDERR "done!\n";

	## add pre-processing tools to the importer if necessary
	foreach ('normalizer', 'splitter', 'tokenizer') {
	    unless ( defined $importer->{$_} ) {
		$importer->{$_} = $self->{$_} if (defined $self->{$_});
	    }
	}

	## convert text to XML with sentence markup
	# print STDERR "ApacheTika: convert to xml ... ";
	my $new_resources = $importer->convert_resource( $tmp_resource, $meta_resource );
	# print STDERR "done!\n";

	## NEW: add meta data about trabslations if they exist (for HTML resources)
	if (ref($new_resources) eq 'ARRAY' && $resource->type() eq 'html' && %translations){
	    my @links = ();
	    foreach (keys %translations){
		push (@links, $_.':'.$translations{$_});
	    }
	    $$new_resources[0]{meta}{language_links} = join(',',@links);
	    &LetsMT::WebService::post_meta( $$new_resources[0]{resource},
					    language_links => join(',',@links) );
	}
	return $new_resources;
	# return $importer->convert_resource( $tmp_resource, $meta_resource );
    }
    return [];
}



sub _read_raw_file{
    my $self =shift;
    my $file = shift;
    my $maxsize = shift;
    open F, '<:raw', $file;
    my $content = undef;
    if ($maxsize){
	sysread(F, $content, $maxsize );
    }
    else{
	$content = do { local $/; <F> };
    }
    close F;
    return $content;

    # open my $fh, '<:raw', $file;
    # my $content = do { local $/; <$fh> };
    # close $fh;
}





## MOVED TO LetsMT::Align::Documents


# ## for HTML:
# ## extract links to translations of the current website
# ## TODO: add various styles and make options to select them
# ## ---> quite hard-coded at this moment but difficult to find generic solutions

# sub _extract_language_links{
#     my $html     = shift;
#     my $thisfile = shift;
#     my $style    = shift || 'vnk';

#     my %trans = ();

#     ##----------------------------------------------------
#     ## VNK style links on websites
#     ## TODO: is this safe enough? (also subject to change)
#     ##----------------------------------------------------
#     if ($style eq 'vnk'){
# 	if ($html=~/<ul\s+class=\"..\">\s*(<li class=\"..\".*?)\<\/ul/s){
# 	    my $match = $1;
# 	    utf8::decode($match); 
# 	    my @links = split(/\<\/li\>/,$match);
# 	    foreach (@links){
# 		my $lang = undef;
# 		my $link = undef;
# 		if (/class=\"(..)\"/){
# 		    $lang = $1;
# 		}
# 		if (/href=\"(.*?)\"/){
# 		    $link = _relative_to_absolute_path($1,$thisfile);;
# 		}
# 		## if it's not a link to a missing language version notification
# 		## and it's not the link to the same page we are at right now
# 		## ---> add the translation!
# 		if ($lang && $link!~/missinglanguageversion/){
# 		    if ($link ne $thisfile){
# 			$trans{$lang} = $link;
# 		    }
# 		}
# 	    }
# 	}
#     }
#     return %trans;
# }


# sub _relative_to_absolute_path{
#     my ($link,$file) = @_;
#     unless ($link=~/^\//){
# 	my @path = split(/\/+/,dirname($file));
# 	my @parts = split(/\/+/,$link);
# 	## move up in file system tree
# 	while ($parts[0]=~/\.\./){
# 	    pop(@path);
# 	    shift(@parts);
# 	}
# 	$link = join('/',@path,@parts);
#     }
#     return $link;
# }



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
