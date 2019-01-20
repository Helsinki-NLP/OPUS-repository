package LetsMT::Import::zip;

=head1 NAME

LetsMT::Import::zip - import handler for C<zip> compressed files

=cut

use strict;
use parent 'LetsMT::Import::tar';

use LetsMT::Tools;
use Data::Dumper;
use File::Basename;
use LetsMT::WebService;
use LetsMT::Import::Archive;


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
    my ($resource, $meta_resource) = @_;

    my $errors = &LetsMT::Tools::scrape_cmd_out_err( 'unzip -t',
        &safe_path( $resource->local_path ) );
    if ( scalar @$errors && $errors->[-1] !~ /^No errors detected/ ) {
        return [ [ $resource, import_log => 'failed to validate as zip' ] ];
    }
    else {
        return [];
    }
}


=head2 C<convert>

=cut

sub convert {
    my $self = shift;
    my ( $resource, $importer, $meta_resource ) = @_;

    my $local_path = $resource->local_path;

    # Get requested resource if necessary
    if ( ( !-e $local_path ) || $self->{-always_fetch} ) {
        return 0 unless ( &LetsMT::WebService::get_resource($resource) );
    }

    my $new_resources = [];

    # initialize archive extraction
    my ($resource_home, $local_home) = 
        $self->initialize_import($resource,$meta_resource);

    ## TODO: do we need this?
    local $ENV{LC_ALL} = 'en_US.UTF-8';
    my $cmd_reader
        = &LetsMT::Tools::cmd_out_reader(
            'unzip -o -d',
            &safe_path( $local_home ),
            &safe_path( $resource->local_path ) );
    my $count=0;
    while ( my $exline = &$cmd_reader ) {
        if ( $exline =~ /^\s*(?:extracting|inflating):\s*$local_home\/(.*?)\s*$/ ){
            my $exfile = $1;

            # resource object for extracted file
            my $ex_resource = $resource->clone;
            $ex_resource->path( join( '/', $resource_home, $exfile ) );

            # metadata object for extracted file (only if meta_resource exists)
            my $exmeta_resource = $meta_resource ? $ex_resource : undef;

            my $cex_resources = 
                $importer->convert_resource($ex_resource,$exmeta_resource);

            # update metadata information (if meta_resource exists)
            $self->update_import_meta($meta_resource, $exfile, $cex_resources);

            foreach my $cex_resource (@$cex_resources) {
                push @$new_resources, $cex_resource;
            }
        }
    }
    return $new_resources;
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
