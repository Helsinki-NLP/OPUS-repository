package LetsMT::Import::Moses;

=head1 NAME

LetsMT::Import::Moses - import handler for I<Moses> files

=head1 DESCRIPTION

L<Moses|http://www.statmt.org/moses/>:
plain-text data used for statistical machine translation systems.

This module expects archives with at least two files
(at present accepts TAR (default) and ZIP archives).

=cut

use strict;
use parent 'LetsMT::Import::Generic';

use File::Basename qw(dirname);
use Data::Dumper;

use LetsMT::Import;
use LetsMT::Tools;
use LetsMT::WebService;
use LetsMT::Import::MosesReader;
use LetsMT::DataProcessing::Normalizer::Whitespace;


=head1 CLASS VARIABLE (public)

=head2 C<$DEFAULT_NORMALIZER>

An instance of the L<whitespace normalizer|LetsMT::DataProcessing::Normalizer::Whitespace>.

=cut

our $DEFAULT_NORMALIZER = new LetsMT::DataProcessing::Normalizer::Whitespace;


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

=cut

sub validate {
    my $self = shift;
    my ($resource) = @_;

    my $file = $resource->local_path;

    if ( $file =~ /\.zip$/ ) {
        my $errors = &LetsMT::Tools::scrape_cmd_out_err( 'unzip -t',
            &safe_path( $resource->local_path ) );
        if ( scalar @$errors && $errors->[-1] !~ /^No errors detected/ ) {
            return [
                [ $resource, import_log => 'failed to validate as zip' ] ];
        }
    }
    else {
        my @errors = grep {/^tar: /} @{
            &LetsMT::Tools::scrape_cmd_out_err( 'tar -t',
                &_file_arg( $resource->local_path ) )
            };
        if ( scalar @errors ) {
            return [
                [ $resource, import_log => 'failed to validate as tar' ] ];
        }
    }

    return [];
}


=head2 C<convert>

=cut

# convert: unpack files and call convert_moses to create the final XML files

sub convert {
    my $self = shift;
    my ( $resource, $importer, $meta_resource ) = @_;

    my @text_resources;
    my $resource_path = dirname( $resource->path );
    my $local_path    = dirname( $resource->local_path );
    my $file          = $resource->local_path;

    if ( $file =~ /\.zip$/ ) {    # zip archive
        my $cmd_reader = &LetsMT::Tools::cmd_out_reader( 'unzip -o -d',
            safe_path($local_path), safe_path($file) );
        while ( my $exline = &$cmd_reader ) {
            if ( $exline =~ /^\s*(?:extracting|inflating):\s*$local_path\/(.*?)\s*$/ )
            {
                my $ex_resource = $resource->clone;
                $ex_resource->path( join( '/', $resource_path, $1 ) );
                push @text_resources, $ex_resource;
            }
        }
    }
    else {    # tar archive
        my $cmd_reader = &LetsMT::Tools::cmd_out_reader( 'tar -xv',
            &_file_arg($file),  '-C', safe_path($local_path) );
        while ( my $exfile = &$cmd_reader ) {
            chomp $exfile;
            unless ( $exfile =~ /\/$/ ) {
                my $ex_resource = $resource->clone;
                $ex_resource->path( join( '/', $resource_path, $exfile ) );
                push @text_resources, $ex_resource;
            }
        }
    }

    # find all parallel documents
    my @new_resources = ();
    my %parallel      = _find_parallel_documents( \@text_resources );

    # convert all sets of parallel documents
    foreach my $base ( keys %parallel ) {
        # the new resource will use the files basename
        my $new_resource = $parallel{$base}[0]->clone();
        $new_resource->path( 'xml/' . $base . '.xml' );

        # create readers and writers
        my $reader = new LetsMT::Import::MosesReader(
            tokenizer  => $importer->{tokenizer},
            normalizer => $importer->{normalizer} || $DEFAULT_NORMALIZER,
            splitter   => $importer->{splitter},
        );

        my $writer = new LetsMT::Import::XCESWriter(
            tokenizer => $importer->{tokenizer},
	    langid    => $importer->{langid_sent}
	    );

        # convert the resource and write monolingual/alignment data
        my $count;

        $reader->open( @{ $parallel{$base} } );
        $writer->open($new_resource);
        while ( my $ap = $reader->read ) {
            $writer->write($ap);
            $count++;
            ## report import progress in metadata
            if ( defined $meta_resource ) {
                unless ( $count % 1000 ) {
                    &LetsMT::WebService::post_meta( $meta_resource,
                        'import_progress', $count );
                }
            }
        }
        $reader->close;
        $writer->close;

        # collect the newly created resources
        my @res = $writer->get_resources;
        foreach my $r ( 0 .. $#res ) {
            push( @{ $new_resources[$r] }, @{ $res[$r] } );
        }
    }

    # import finished ... return the newly created resource objects
    if ( defined $meta_resource ) {
        &LetsMT::WebService::del_meta( $meta_resource, 'import_progress' );
    }
    return $new_resources[0];
}


=head1 INTERNAL CLASS METHODS

=head2 C<_file_arg>

Form correct argument for C<tar>, depending on whether the file
is C<gzip> compressed or not.

=cut

sub _file_arg {
    my ($file) = @_;
    if ( $file =~ /gz$/ ) {
        return '-zf ' . safe_path($file);
    }
    else {
        return '-f ' . safe_path($file);
    }
}


=head2 C<_find_parallel_documents>

=cut

sub _find_parallel_documents {
    my $resources = shift;
    my %parallel  = ();
    foreach my $res ( @{$resources} ) {
        my $path = $res->path();
        $path =~ s/^(uploads\/)?moses\/(.*)\.[^\.]+$/$2/;
        push( @{ $parallel{$path} }, $res );
    }
    return %parallel;
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
