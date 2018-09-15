package LetsMT::Import::tar;

=head1 NAME

LetsMT::Import::tar - import handler for C<tar> archives

=cut

use strict;
use parent 'LetsMT::Import::Generic';

use File::Basename qw/basename/;
use Data::Dumper;
use XML::LibXML;

use LetsMT::Tools;
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
    my $self  = shift;
    my ($resource,$meta_resource) = @_;

    my @errors = grep {/^tar: /} @{
        &LetsMT::Tools::scrape_cmd_out_err( 
             'tar -t',
             &_file_arg( $resource->local_path ) )
        };
    if ( scalar @errors ) {
        return [ [ $resource, import_log => 'failed to validate as tar' ] ];
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

    my @new_resources;

    # initialize archive extraction
    my ($resource_home, $local_home) = 
        $self->initialize_import($resource,$meta_resource);

    # unpack the tar archive

    my $cmd_reader
        = &LetsMT::Tools::cmd_out_reader( 'tar -xv',
        &_file_arg( $resource->local_path ),
        '-C',
        &safe_path( $local_home ) );

    # run through all unpacked resources and import them

    while ( my $exfile = &$cmd_reader ) {
        chomp $exfile;
	next if (basename($exfile)=~/^\./);       # skip files starting with .
        unless ( $exfile =~ /\/$/ ) {

            # resource object for extracted file
            my $ex_resource = $resource->clone;
            $ex_resource->path( join( '/', $resource_home, $exfile ) );

            # metadata object for extracted file (only if meta_resource exists)
            my $exmeta_resource = $meta_resource ? $ex_resource : undef;

            my $cex_resources = 
                $importer->convert_resource($ex_resource,$exmeta_resource);

            # update metadata information (if meta_resource exists)
            $self->update_import_meta($meta_resource, $exfile, $cex_resources);

            # add all new resources to our list of imported files
            foreach my $cex_resource (@$cex_resources) {
                push @new_resources, $cex_resource;
            }
        }
    }
    return \@new_resources;
}





sub initialize_import{
    my $self=shift;
    my ($resource,$meta_resource) = @_;

    my $resource_path = $resource->path;
    $resource_path =~s/\.[^.]+(\.gz)?$// or $resource_path .= '.extracted';
    my $homedir_resource = $resource->clone;
    $homedir_resource->path( $resource_path );

    my $local_path = $homedir_resource->local_path;
    &LetsMT::Tools::mkdir( $local_path );

    # delete previous import counts
    # and safe extraction homedir 
    # to make metadata for extracted files accessible

    if ($meta_resource){
        &LetsMT::WebService::del_meta(
             $meta_resource,
             "import_success"       => undef,
             "import_failed"        => undef,
             "import_empty"         => undef,
             "import_success_count" => undef,
             "import_failed_count"  => undef,
             "import_empty_count"   => undef);
        &LetsMT::WebService::post_meta(
             $meta_resource,
             "import_homedir"       => $resource_path);
    }

    $self->{countOK}=0;
    $self->{countEmpty}=0;
    $self->{countFailed}=0;

    return ($resource_path, $local_path);
}


sub update_import_meta{
    my $self      = shift;
    my ($resource,$filename,$imported) = @_;

    # do nothing if no resource is given
    return unless $resource;

    if ($imported){
        if (scalar @$imported){
            $self->{countOK}++;
            &LetsMT::WebService::put_meta(
                $resource,
                "import_success" => $filename);
        } else {
            $self->{countEmpty}++;
            &LetsMT::WebService::put_meta(
                $resource,
                "import_empty" => $filename);
        }
    } else {
        $self->{countFailed}++;
        &LetsMT::WebService::put_meta(
            $resource,
            "import_failed" => $filename);
    }

    &LetsMT::WebService::post_meta(
        $resource,
        "import_success_count" => $self->{countOK},
        "import_failed_count"  => $self->{countFailed},
        "import_empty_count"   => $self->{countEmpty}
    );
}


=head1 CLASS METHOD (private)

=head2 C<_file_arg>

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
