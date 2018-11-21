package LetsMT::Repository::API::Storage;

=head1 NAME

LetsMT::Repository::API::Storage - API class for the REST URI C<storage>

=head1 SYNOPSIS

 use LetsMT::Repository::API::Storage;

 my $storage = LetsMT::Repository::API::Storage;
 $storage->new($r);
 $storage->process;

=head1 DESCRIPTION

This class implements the functionality available through the REST URI
C<storage> - GET, PUT, POST and DELETE - and returns the result as a XML string.

=cut

use strict;
use parent 'LetsMT::Repository::API';

use open qw(:std :utf8);

use File::Temp qw(tempfile);
use Apache2::Request;
use Apache2::Upload;

use LetsMT;
use LetsMT::Tools;
use LetsMT::Repository::StorageManager;
use LetsMT::Repository::JobManager;
use LetsMT::Repository::Result;

use LetsMT::Resource;

use LetsMT::Repository::Err;
use Log::Log4perl qw(get_logger :levels);
use Data::Dumper;

### CLASS METHOD ############################################################
# Usage      : LetsMT::Repository::API::Storage->new($r);
# Purpose    : Constructor, creates an instance of API::Storage class
# Returns    : Blessed hash_ref inherriting from LetsMT::Repository::API
# Parameters : hash_ref storing details from the mod_perl request
# Throws     : no exceptions
# Comments   : Overwrites constructor/factory method from parent

sub new {
    my ( $class, $r_ref ) = @_;
    #get_logger(__PACKAGE__)->debug( Dumper($r_ref) );
    bless $r_ref, $class;
}


=head2 C<get>

List all slots or the content of a slot, branch or path,
or the content of a file.

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::API::Storage->get();
# Purpose    : Lists all slots or the content of a slot, branch or path or content of a file
# Returns    : The result of the request as XML string
# Parameters : none
# Throws     : no exceptions
# Comments   : Overwrites get method from parent

sub get {
    my $self   = shift;
    my $result = undef;

    if ( $self->{args}->{action} && $self->{args}->{action} eq "download" ) {
        my $target = undef;

        LetsMT::Repository::StorageManager::download_storage(
            path    => $self->{path_elements},
            rev     => $self->{args}->{rev},
            uid     => $self->{args}->{uid},
            target  => \$target,
            archive => $self->{args}->{archive},
        );

        get_logger(__PACKAGE__)->debug( 'got target: ' . $target );

        return \$target;  # Return the temp location of the download target as string ref
    }
    elsif ( $self->{args}->{action} && $self->{args}->{action} eq "cat" ) {
        my $range_option = {};

        $range_option->{from} = $self->{args}->{from}
            if ( defined $self->{args}->{from}
                && $self->{args}->{from} =~ /^[0-9]+$/
            );

        $range_option->{to} = $self->{args}->{to}
            if ( defined $self->{args}->{to}
                && $self->{args}->{to} =~ /^[0-9]+$/
            );

        LetsMT::Repository::StorageManager::cat_storage(
            \$result,
            $self->{path_elements},
            $self->{args}->{uid},
            $range_option,
            $self->{args}->{rev}
        );
    }
    else {
        LetsMT::Repository::StorageManager::list_storage(
            \$result,
            $self->{path_elements},
            $self->{args}->{uid},
            $self->{args}->{rev}
        );
    }

    # Success if we got here, prepare Result object and return it
    my $result_obj = LetsMT::Repository::Result->new(
        type      => 'ok',
        code      => 0,
        operation => 'GET',
        location  => $self->{path_info},
        lists     => \$result,
    );

    return $result_obj->get_xml_result();
}


=head2 C<put>

Upload data and optionally import it.

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::API::Storage->put();
# Purpose    : Uploads data and optionally imports it
# Returns    : The result of the request as XML string
# Parameters : none
# Throws     : no exceptions
# Comments   : Overwrites get method from parent

sub put {
    my $self = shift;

    my $payload        = undef;
    my $message_create = undef;
    my $message_submit = undef;

    # make a copy of the old metadata record (archive revisions!)
    &_archive_meta(join( "/", @{ $self->{path_elements} }));

    # Receive the payload and write it to $payload
    &_get_payload( $self->{r}, \$payload );

    LetsMT::Repository::StorageManager::create_storage(
        message => \$message_create,
        path    => $self->{path_elements},
        uid     => $self->{args}->{uid},
        gid     => $self->{args}->{gid},
        payload => $payload ? $payload->{file} : undef,
        type    => $self->{args}->{type}
    );

    my $path = join( "/", @{ $self->{path_elements} } );

    &_post_meta( $path, status => 'updated' );

    # If URL argument action=import is given, import the uploaded resouces
    if ( defined $self->{args}->{action}  &&  $self->{args}->{action} eq "import" ) {
        # create and submit import job if
        # there is a file in payload && it goes to the uploads dir
        if ( defined $payload->{file}
            && ( $self->{path_elements}[2] eq $LetsMT::REPOSITORY_UPLOAD_DIR )
        ) {
            my $target = [ @{ $self->{path_elements} } ];
            my $slot   = shift(@$target);
            my $branch = shift(@$target);
            my $upload = join( '/', @$target );

	    ## path to the job description file
	    my $jobfile = join('/','storage',$slot,$branch,
			       'jobs','import',@$target);
	    $jobfile .= '.xml';

            get_logger(__PACKAGE__)->debug( 'upload: ' . $upload );

            # create import job
            LetsMT::Repository::JobManager::create_job(
                # path   => "$path.import_job",
                path     => $jobfile,
                uid      => $self->{args}->{uid},
                walltime => 5,
                queue    => 'letsmt',
                commands => [ join( ' ',
                    'letsmt_import',
                    '-u' => safe_path($branch),
                    '-s' => safe_path($slot),
                    '-p' => safe_path($upload),
                ) ],
            );

            # submit job
	    my $jobID = LetsMT::Repository::JobManager::submit(
		message => \$message_submit,
		# path    => "$path.import_job",
		path    => $jobfile,
		uid     => $self->{args}->{uid},
            );

            # add some information to the meta database
            my $corpus = join( "/", ( $slot, $branch ) );
            my $metaDB = new LetsMT::Repository::MetaManager();
            $metaDB->open() || raise( 8, "open metadata database", 'error' );
            $metaDB->post(
                $path,
                { status  => 'waiting in import queue',
		  job_id  => $jobID }
            );

            # update queue information on branch level
            my @failed = $metaDB->get( $corpus, 'import_failed' );
            if ( grep( $_ eq $upload, @failed ) ) {
                $metaDB->delete( $corpus, { 'import_failed' => $upload } );
            }
            $metaDB->put( $corpus, { 'import_queue' => $upload } );
            $metaDB->close();
        }
    }

    # Update meta data
    # TODO: set meta data to status=modified
    #$args{status} = 'modified' if ( !exists $args{status} );
    #$api_call_matrix{metadata_POST}->();

    # Success if we got here, prepare Result object and return it
    my $result_obj = new LetsMT::Repository::Result(
        type      => 'ok',
        code      => 0,
        operation => 'PUT',
        location  => $self->{path_info},
        message   => $message_create .
            ( ( length $message_submit ) ? ",$message_submit" : "" ),
    );

    # don't wait for cleaning up and remove payload immediately
    unlink($payload->{file}) if (-f $payload->{file});

    return $result_obj->get_xml_result();
}


=head2 C<post>

Create or copy a slot, branch, path, or upload data.

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::API::Storage->post();
# Purpose    : Creates or copies a slot, branch, path or uploads data
# Returns    : The result of the request as XML string
# Parameters : none
# Throws     : no exceptions
# Comments   : Overwrites get method from parent

sub post {
    my $self = shift;

    my $message = undef;

    my $logger = get_logger(__PACKAGE__);

    if ( exists( $self->{args}->{action} )
        && ( $self->{args}->{action} eq 'copy' ) )
    {
        &LetsMT::Repository::StorageManager::copy_branch(
            message => \$message,
            path    => $self->{path_elements},
            uid     => $self->{args}->{uid},
            gid     => $self->{args}->{gid},
            dest    => $self->{args}->{dest}
        );

        # Copy all metadata from old to new branch
        my $metaDB = new LetsMT::Repository::MetaManager();
        $metaDB->open() || raise( 8, "open metadata database", 'error' );
        my $oldpref = $self->{path_elements}[0] . '/'
            . $self->{path_elements}[1];    # need to copy metadata as well!
        my $newpref = $self->{path_elements}[0] . '/' . $self->{args}->{dest};
        $metaDB->copy( $oldpref, $newpref, $self->{args}->{dest} );

        # Change some metadata like name (modif?, create?) on the new branch
        my %branch_meta_hash = (
            'name' => $self->{args}->{dest},
            #'modif'  => ?,
            #'create' => ?,
        );
        $logger->debug( "writing meta data on $newpref: " . Dumper(%branch_meta_hash) );
        $metaDB->post( $newpref, \%branch_meta_hash )
            or $logger->error( "could not write meta data for $newpref", 'error' );
        $metaDB->close();
    }
    else {
        my $payload = undef;

        # make a copy of the old metadata record (archive revisions)
        &_archive_meta(join( "/", @{ $self->{path_elements} }));

        &_get_payload( $self->{r}, \$payload );

        LetsMT::Repository::StorageManager::create_storage(
            message => \$message,
            path    => $self->{path_elements},
            uid     => $self->{args}->{uid},
            gid     => $self->{args}->{gid},
            payload => $payload ? $payload->{file} : undef,
            type    => $self->{args}->{type},
        );

        &_post_meta( join( "/", @{ $self->{path_elements} } ),
            status => 'created' );

        # don't wait for cleaning up and remove payload immediately
        unlink($payload->{file}) if (-f $payload->{file});
    }

    # Success if we got here, prepare Result object and return it
    my $result_obj = LetsMT::Repository::Result->new(
        type      => 'ok',
        code      => 0,
        operation => 'POST',
        location  => $self->{path_info},
        message   => $message,
    );

    return $result_obj->get_xml_result();
}


=head2 C<delete>

Delete a slot, branch or content of a path.

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::API::Storage->delete();
# Purpose    : Deletes a slot, branch or content of a path
# Returns    : The result of the request as XML string
# Parameters : none
# Throws     : no exceptions
# Comments   : Overwrites get method from parent

sub delete {
    my $self = shift;

    LetsMT::Repository::StorageManager::delete_storage(
        $self->{path_elements},
        $self->{args}->{uid}
    );

    # Delete metadata belonging to deleted resource starting with the current path
    my $metaDB = new LetsMT::Repository::MetaManager();
    my $delete_path = join( "/", @{ $self->{path_elements} } );
    $metaDB->open() || raise( 8, 'open metadata database', 'fatal' );
    my $count = $metaDB->delete_recursive($delete_path);
    $metaDB->close() || raise( 8, 'close metadata database', 'fatal' );
    get_logger(__PACKAGE__)->info(
        "Deleted all ($count) meta data entries starting with '$delete_path'"
    );

    # Success if we got here, prepare Result object and return it
    my $result_obj = LetsMT::Repository::Result->new(
        type      => 'ok',
        code      => 0,
        operation => 'DELETE',
        location  => $self->{path_info},
        message   => 'Deleted ' . $self->{path_info},
    );

    return $result_obj->get_xml_result();
}


=head1 INTERNAL UTILITY METHODS

=head2 C<_get_payload>

 $api->_get_payload( $r, $payload_ref )

Receive the payload from PUT or POST
and write it to a path.

Has no defined return value.

=cut

### INTERNAL UTILITY METHOD ###################################################
# Usage      : LetsMT::Repository::API::Storage->_get_payload($r, $payload);
# Purpose    : Receives the payload from PUT and POST and writes it to payload
# Returns    : nothing, but writes to in-argument payload
# Parameters : ref till mod_perl r-object and payload ref
# Throws     : no exceptions
# Comments   :

sub _get_payload() {

    my $r = new Apache2::Request(
        shift,
        DISABLE_UPLOADS => 0,
        TEMP_DIR        => $ENV{UPLOADDIR}
    );
    my $payload = shift;

    $r->parse;

    my $uploaded_file = $r->upload('payload'); 

    if ($uploaded_file) { ## POST request
        $$payload = {
            file => $uploaded_file->tempname(),
            size => $uploaded_file->size(),
        };
        get_logger(__PACKAGE__)
            ->info( 'Received file via POST: ' . Dumper($$payload) );
    }
    else {  ## PUT request
        my ( $putfh, $put ) = tempfile(
            'payload_XXXXXXXX',
            DIR    => $ENV{UPLOADDIR},
            UNLINK => 1
        );

        binmode $putfh;
        my $buf;
        my $cnt         = 0;
        my $upload_size = 0;

        while ( $cnt = $r->read( $buf, 65536 ) ) {
            print $putfh $buf;
            $upload_size += $cnt;
        }
        close($putfh)
            || raise( 8, "Can't close upload file handle!", 'error' );

        # if file size is 0 then we interpret it as a directory
        # thus with PUT we can't upload empty files, for this we have to use POST
        if ( -s $put ) {
            $$payload = {
                file => $put,
                size => $upload_size,
            };
            get_logger(__PACKAGE__)
                ->info( 'Received file via PUT: ' . Dumper($$payload) );
        }
    }
}


=head2 C<_post_meta>

=cut

sub _post_meta {
    my $path = shift;
    my %meta = @_;

    my $metaDB = new LetsMT::Repository::MetaManager();
    $metaDB->open() or raise( 8, "open metadata database", 'error' );
    $metaDB->post( $path, \%meta );
    $metaDB->close();
}


=head2 C<_put_meta>

=cut

sub _put_meta {
    my $path = shift;
    my %meta = @_;

    my $metaDB = new LetsMT::Repository::MetaManager();
    $metaDB->open() or raise( 8, "open metadata database", 'error' );
    $metaDB->put( $path, \%meta );
    $metaDB->close();
}


=head2 C<_archive_meta>

=cut

# make a copy of metadata from the current resource revision ....
# --> save metadata history!

sub _archive_meta {
    my $path = shift;

    my $resource = &LetsMT::Resource::make_from_storage_path($path);
    my $revision = $resource->revision();

    if ($revision){
        my $metaDB = new LetsMT::Repository::MetaManager();
        $metaDB->open() or raise( 8, "open metadata database", 'error' );
        my $meta = $metaDB->get( $path );
        if (keys %{$meta}){
            $$meta{'_METADATATYPE_'} = 'history';
            $metaDB->post( "$path\@$revision", $meta );
        }
        $metaDB->close();
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
