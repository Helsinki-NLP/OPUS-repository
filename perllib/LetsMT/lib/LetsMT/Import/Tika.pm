package LetsMT::Import::Tika;

=head1 NAME

LetsMT::Import::Tika - generic import handler for documents handled by Tika

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

use IPC::Run qw(run);

use File::Path;

use Log::Log4perl qw(get_logger :levels);

my $path_to_tika = $ENV{LETSMTROOT} . '/lib/tika-app-1.18.jar';


=head1 CONSTRUCTOR

=cut

sub new {
    my $class = shift;
    my %self  = @_;

    # pattern for matching expected tika output in validation
    # accept as long as there is a type detected
    $self{content_type_pattern} = 'Content-Type:' unless $self{content_type_pattern};

    bless \%self, $class;
    return \%self;
}


=head1 METHODS

=head2 C<validate>

 $handler->validate ($resource)

Validates that C<$resource> is a doc file.

=cut

sub validate {
    my $self = shift;
    my ($resource) = @_;

    # document type
    my $type = $self->{type} || $resource->type();

    my $logger = get_logger(__PACKAGE__);

    # run TIKA
    my ( $success, $ret, $out, $err ) = run_cmd(
        'java', '-jar',
        $path_to_tika,
        '-m', $resource->local_path
    );

    # check if the content type matches
    if ($success){
        my %meta =  &_extract_meta($out);
        if ($out=~/$$self{content_type_pattern}/s){
            return ( [] , [[$resource,%meta]] );
        }

        ## TODO: should we store TIKA output somewhere? (in metaDB? error log?)

        $logger->warn("failed to validate as $type!");
        return [
            [ $resource, import_log => "failed to validate as $type" ]
        ];
    }

    # something failed! --> check why!
    if ( $err =~ /Unable to access jarfile/s ){
        raise( 8, 'Unable to access jarfile at ' . $path_to_tika, 'error' );
    }

    ## do not fail on exception but return validation failure!
    if ( $err =~ /Exception in thread/m ) {
        $logger->debug( 'tika output: ', $out.$err );
    }

    return [
        [ $resource, import_log => "failed to validate as $type" ]
    ];
}

sub _extract_meta{
    my $output = shift;
    my %meta = ();
    my @lines = split (/\n/,$output);
    foreach (@lines){
        my ($key,$value) = split(/:\s/);
        # to be on the safe side: replace all non-basic characters with '_'
        $key =~s/[^a-zA-Z0-9\.\-]/\_/;
        $meta{'TIKA_'.$key} = $value;
    }
    return %meta;
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

    $logger->debug('trying to convert');

    # document type
    my $type = $self->{type} || $resource->type();

    my $type_pattern  = $self->{type_pattern} || $type;
    my $text_resource = $resource->convert_type( $type_pattern, 'txt' );
    File::Path::make_path( $text_resource->path_down->local_path );

    ## try to convert to text
    my @cmd = (
        'java', '-jar',
        $path_to_tika,
        '-t',
        '-eUTF-8',
        $resource->local_path
    );
    if (pipe_out_cmd_quiet( $text_resource->local_path, @cmd )){

        ## add pre-processing tools to the importer if necessary
        foreach ('normalizer', 'splitter', 'tokenizer') {
            unless ( defined $importer->{$_} ) {
                $importer->{$_} = $self->{$_} if (defined $self->{$_});
            }
        }

        ## convert text to XML
        return $importer->convert_resource( $text_resource, $meta_resource );
    }
    return [];
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
