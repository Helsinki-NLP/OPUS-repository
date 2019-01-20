package LetsMT::Import::PDF;

=head1 NAME

LetsMT::Import::PDF - import handler for C<pdf> files

=head1 DESCRIPTION

PDF: the Portable Document Format.

=cut

use strict;
use parent 'LetsMT::Import::Generic';

use LetsMT;
use LetsMT::Tools;
use LetsMT::DataProcessing::Splitter;
use LetsMT::WebService;

# alternative: use Tika!
# use LetsMT::Import::Tika;
use LetsMT::Import::ApacheTika;

# needed for the layout-mode conversion
use IPC::Run qw(run timeout);
use File::Path;
use Text::PDF2XML;
use Data::Dumper;
use Log::Log4perl qw(get_logger :levels);


=head1 PUBLIC MODULE VARIABLES

Declared as C<our> allowing access wherever the module is being C<use>d.


=head2 C<$DEFAULT_MODE>

The default mode of conversion (see LetsMT.pm). Possible modes are: 

 standard (standard mode of pdftotext)
 raw (raw text extraction)
 layout (text extraction with layout + post-processing for column detection)
 tika (use Apache Tika instead)


=head2 C<$DEFAULT_SPLITTER>

The default splitter algorithm (europarl).

=cut

our $DEFAULT_MODE     = $LetsMT::IMPORT_PDF_MODE;
our $DEFAULT_SPLITTER = $LetsMT::IMPORT_SPLITTER;

## timeout in seconds for pdf2xml
## fallback = convert_raw_cmd
our $PDF2XML_TIMEOUT  = 300;

# C<$MODE_TO_CMD>
#
# A mapping of valid conversion modes to the actual code that converts.

my $MODE_TO_CMD = {
    'standard' => \&convert_standard_cmd,
    'raw'      => \&convert_raw_cmd,
    'layout'   => \&convert_layout_cmd,
    ## prefer running as external command to avoid
    ## that the whole process breaks if conversion fails
    'combined' => \&convert_pdf2xml_cmd,
    'pdf2xml'  => \&convert_pdf2xml_cmd,
    # 'combined' => \&convert_pdf2xml,
    # 'pdf2xml'  => \&convert_pdf2xml,
};

## intermediate format used for conversion in each mode
## (txt will be used as default)
my %MODE_TMP_FORMAT = (
    'standard' => 'txt',
    'raw'      => 'txt',
    'layout'   => 'txt',
    'combined' => 'rawxml',
    'pdf2xml'  => 'rawxml'
);


=head1 CONSTRUCTOR

 $handler = new LetsMT::Import::PDF (%OPTIONS)

OPTIONS:

 mode
  - possible values: layout, standard, raw
 splitter
  - a pre-created splitter object
 splitter_method
  - used in 'standard' mode to create a new splitter if no splitter
    object is given; default: the value of C<DEFAULT_SPLITTER>.

=cut

sub new {
    my $class = shift;
    my %self  = @_;

    $self{mode} = $DEFAULT_MODE  unless ( defined $self{mode} );

#    $self{tika} = new LetsMT::Import::Tika(
    $self{tika} = new LetsMT::Import::ApacheTika(
	type => 'pdf',
	type_pattern => '(?:pdf|PDF)',
	content_type_pattern => 'Content-Type: application\/pdf',
	@_
        );

    # # return a tika importer if mode = tika
    # # set type and type patterns for PDF documents
    # if ($self{mode}=~/tika/i){
    #     return new LetsMT::Import::Tika(
    #         type => 'pdf',
    #         type_pattern => '(?:pdf|PDF)',
    #         content_type_pattern => 'Content-Type: application\/pdf',
    #         @_
    #     );
    # }

    bless \%self, $class;
    initialize(\%self);

    return \%self;
}


=head1 METHODS

=head2 C<mode>

 $handler->mode ($mode)

Set the conversion mode.

=cut

sub set_mode {
    my ( $self, $mode ) = @_;
    unless ($mode eq 'tika'){
	if ( $MODE_TO_CMD->{$mode} ) {
	    $self->{cmd} = $MODE_TO_CMD->{$mode};
	}
    }
    $self->{mode} = $mode;
}


sub initialize{
    my $self=shift;
    unless ($self->{mode} eq 'tika'){
	if ( $MODE_TO_CMD->{ $self->{mode} } ) {
	    $self->{cmd} = $MODE_TO_CMD->{ $self->{mode} };
	}
	else {
	    get_logger(__PACKAGE__)
            ->warn( "No way to execute mode: '$self->{mode}' use one of [ "
                . join( ', ', grep { $MODE_TO_CMD->{$_} } keys %$MODE_TO_CMD )
                . ']'
            );
	}
    }

    my $SplitterMethod = $self->{splitter_method} || $DEFAULT_SPLITTER;
    ## in standard mode: don't merge lines!
    if ( $self->{mode} eq 'standard' ) {
        unless ( defined $self->{splitter} ) {
            $self->{splitter} = new LetsMT::DataProcessing::Splitter(
                method         => $SplitterMethod,
                separate_lines => 1
            );
        }
    }
    $self->SUPER::initialize;
}


=head2 C<validate($resource)>

Validate that C<$resource> is a pdf file.

=cut

sub validate {
    my $self = shift;
    my ($resource) = @_;

    ## TODO: do we ever get tika here?
    if ($self->{mode} eq 'tika'){
	return $self->{tika}->validate(@_);
    }

    # TODO: should we safe the error messages in case validation fails!
    #       --> upload $err as file or put into MetaDB ....

    my ($success,$ret,$out,$err) = &run_cmd('pdfinfo', $resource->local_path);
    if ($err =~/(\A|\n)Error: /s){
        return [
            [ $resource, import_log => "failed to validate as PDF" ]
        ];
    }
    return [];
}


=head2 C<convert>

 $handler->convert ($resource, $importer, $meta_resource)

Convert C<$resource> to text and import the resulting text file.

=cut

sub convert {
    my $self = shift;
    my ( $resource, $importer, $meta_resource ) = @_;

    # change conversion mode if necessary
    if ( exists $importer->{mode} ) {
        $self->set_mode( $importer->{mode} );
    }

    if ($self->{mode} eq 'tika'){
	return $self->{tika}->convert(@_);
    }

    # Get requested resource if necessary
    if ( ( !-e $resource->local_path ) || $self->{-always_fetch} ) {
        return 0 unless ( &LetsMT::WebService::get_resource($resource) );
    }

    ## try to convert to text
    # my $tmp_resource = $resource->clone;
    my $tmp_format = $MODE_TMP_FORMAT{$self->{mode}} || 'txt';
    # $tmp_resource->{path} =~s/\.pdf$/.$tmp_format/i;
    my $tmp_resource = $resource->convert_type( 'pdf', $tmp_format );
    &File::Path::make_path( $tmp_resource->path_down->local_path );

    if ( $self->{cmd}->( $resource, $tmp_resource ) ) {

        ## add pre-processing tools to the importer if necessary
        foreach ('normalizer','splitter','tokenizer'){
            unless ( defined $importer->{$_} ) {
                $importer->{$_} = $self->{$_} if (defined $self->{$_});
            }
        }

        ## convert to final XML
        $tmp_resource->encoding('utf-8');    # set character encoding
        return $importer->convert_resource( $tmp_resource, $meta_resource );
    }
    return [];
}


=head1 CLASS METHODS

=head2 C<convert_standard_cmd>

 $data = LetsMT::Import::PDF::convert_standard_cmd ($resourcce, $text_resource)

Convert a pdf to text in C<standard> mode.

=cut

sub convert_standard_cmd {
    my ( $resource, $text_resource ) = @_;
    return &run_cmd(
        'pdftotext','-enc','UTF-8',
        $resource->local_path,
        $text_resource->local_path
	);
}


=head2 C<convert_raw_cmd>

 $data = LetsMT::Import::PDF::convert_raw_cmd ($resourcce, $text_resource)

Convert a pdf to text in C<raw> mode.

=cut

sub convert_raw_cmd {
    my ( $resource, $text_resource ) = @_;
    return &run_cmd(
        'pdftotext','-raw','-enc','UTF-8',
        $resource->local_path,
        $text_resource->local_path);
}


=head2 C<convert_layout_cmd>

 $data = LetsMT::Import::PDF::convert_layout_cmd ($resourcce, $text_resource)

Convert a pdf to text in C<layout> mode,
detecting columns with the help of a column-detection script.

=cut

sub convert_layout_cmd {
    my ( $resource, $text_resource ) = @_;

    ## use IPC::Run to pipe the PDF through pdftotext and letsmt_convert_column
    return run 
        [ 'pdftotext','-layout','-enc','UTF-8',$resource->local_path,'-'], '|',
        [ 'sed','s/\f/\n/' ], '|',
        [ 'letsmt_convert_columns' ],
        '>', $text_resource->local_path;
}


=head2 C<convert_pdf2xml_cmd>

 $data = LetsMT::Import::PDF::convert_pdf2xml_cmd ($resourcce, $text_resource)

Convert a pdf to xml using pdf2xml.

=cut

sub convert_pdf2xml_cmd {
    my ( $resource, $xml_resource ) = @_;

    ## use IPC::Run to pipe the PDF through pdf2xml
    ## NEW: use a timeout of 5 minutes
    ##      fallback = 
    my $err = undef;
    my $out = $xml_resource->local_path;
    eval {
	return run [ 'pdf2xml', $resource->local_path ], 
	           '>', $out, 
	           \$err, timeout($PDF2XML_TIMEOUT);
    };
    print STDERR $@ if ($@);

    ## need to revert to text output for the fallback mode
    ## TODO: any problems here?
    $xml_resource->type( 'txt' );
    &File::Path::make_path( $xml_resource->path_down->local_path );
    return &convert_raw_cmd($resource, $xml_resource);

## OLD: pdf2xml without timeout
##
#    return run 
#        [ 'pdf2xml',$resource->local_path ],
#	'>', $xml_resource->local_path;
}


=head2 C<convert_pdf2xml>

 $data = LetsMT::Import::PDF::convert_pdf2xml ($resourcce, $text_resource)

Convert a pdf to xml using the pdf2xml library.

=cut

sub convert_pdf2xml {
    my ( $resource, $xml_resource ) = @_;

    ## use IPC::Run to pipe the PDF through pdf2xml
    pdf2xml( $resource->local_path, 
	     output => $xml_resource->local_path );
    return 1;
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
