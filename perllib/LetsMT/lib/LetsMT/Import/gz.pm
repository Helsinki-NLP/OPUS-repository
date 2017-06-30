package LetsMT::Import::gz;

=head1 NAME

LetsMT::Import::gz - import handler for C<gzip> compressed files

=cut

use strict;
use parent 'LetsMT::Import::Generic';

use LetsMT::Tools;
use LetsMT::WebService;
use Data::Dumper;


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
    my ( $resource, $importer ) = @_;

    my $errors = &LetsMT::Tools::scrape_cmd_out_err( 'gunzip -t',
        $resource->local_path );
    if ( scalar @$errors ) {
        return [ [ $resource, import_log => 'failed to validate as gz' ] ];
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

    # Get requested resource if necessary
    if ( ( !-e $resource->local_path ) || $self->{-always_fetch} ) {
        return 0 unless ( &LetsMT::WebService::get_resource($resource) );
    }

    if ( &run_cmd('gunzip','-f',$resource->local_path ) ){
        my $new_resource = $resource->strip_suffix;
        return $importer->convert_resource( $new_resource, $meta_resource );
    }
    else {
        return [];
    }
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