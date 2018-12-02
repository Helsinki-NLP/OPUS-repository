package LetsMT::WebService;

=head1 NAME

LetsMT::WebService - low level repository manager for C<Resource>s

=head1 DESCRIPTION

All functions accept additional key-value pairs as parameters that will be added
as a query form to the request.

=cut


use strict;
use Data::Dumper;

use LWP::UserAgent;
use HTTP::Request;
use HTTP::Request::Common;
use HTTP::Response;
use HTTP::Headers;
use Net::SSL; ## for SSL to work with LWP > 6.0

use File::Basename 'dirname';
use File::Path;
use XML::Simple;
use Log::Log4perl qw(get_logger :levels);

use LetsMT::Tools;
use LetsMT::Resource;
use LetsMT::Repository::Err;

use open qw(:std :utf8);

my $archive_suffix = '.zip';
my $VERBOSE        = 0;

my $SSL_timeout = $ENV{SSL_TIMEOUT} || 7200;


# ------------------------------------------------------------------------------
# USER AGENT
# ------------------------------------------------------------------------------

=head2 C<user_agent>

 $ua = user_agent( $server )

Return a new LWP user-agent object that can handle all the HTTPS requests,
setting the SSL environment variables to point to the proper SSL certificate
and key files for the server C<$server>.

It is okay if C<$server> is a complete URL.

=cut

sub user_agent {
    my $server = shift;

    $server =~ s{https://}{};    #take away 'https://'
    $server =~ s{[:/].*}{};      #take away everything after the server name

    $server = $ENV{LETSMTHOST}  if ( $server =~ /^localhost/ );

    # $ENV{HTTPS_CA_FILE}   = $ENV{LETSMT_CACERT};
    $ENV{HTTPS_CA_FILE}   = '/etc/ssl/'.$server.'/ca.crt';
    $ENV{HTTPS_CERT_FILE} = '/etc/ssl/'.$server.'/user/certificates/developers@localhost.crt';
    $ENV{HTTPS_KEY_FILE}  = '/etc/ssl/'.$server.'/user/keys/developers@localhost.key';
    # $ENV{HTTPS_DEBUG} = 1;
    # $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;

    return new LWP::UserAgent(
        keep_alive    => 1,
        timeout       => $SSL_timeout,
        show_progress => $VERBOSE,
    );
}


# ------------------------------------------------------------------------------
# MISC
# ------------------------------------------------------------------------------

=head1 FUNCTIONS - General

=head2 C<request>

 $response = LetsMT::WebService::request ($method, $uri)

Issue a general HTTP request.

Returns an C<HTTP::Response> object.

=cut

sub request {
    my $method = shift;
    my $url    = shift;
    return &user_agent($url)->request(
        new HTTP::Request( $method, $url )
    );
}


=head2 C<letsmt_request>

 $response = letsmt_request ($method, $make_url_ref, @params)

Issue a general HTTP request.
C<$make_url_ref> is a code reference that makes a URI using the given C<@params>.

Returns an C<HTTP::Response> object.

=cut

sub letsmt_request {
    my $method       = shift;
    my $make_url_ref = shift;
    my ($url, $server) = $make_url_ref->( @_ );
    return &user_agent($server)->request(
        new HTTP::Request( $method, $url )
    );
}


=head2 C<request_result>

 request_result ($method, $url, @params)

Issue a general HTTP request, and return the result.

Returns:

* In a scalar context, the decoded content if the method is GET,
otherwise the success.

* In a list context, the success, the decoded content (body),
the HTTP status code (100--505), and the response object itself.

=cut

sub request_result {
    my $method = shift;

    my $res = request( $method, @_ );
    return wantarray
        ? ( $res->is_success, $res->decoded_content, $res->code, $res )
        : ($method eq 'GET')
            ? $res->decoded_content
            : $res->is_success;
}


=head2 C<letsmt_request_result>

 letsmt_request_result ($method, $make_url_ref, @params)

Issue a general HTTP request, and return the result.
C<$make_url_ref> is a code reference that makes a URI using the given C<@params>.

Returns:

* In a scalar context, the decoded content if the method is GET,
otherwise the success.

* In a list context, the success, the decoded content (body),
the HTTP status code (100--505), and the response object itself.

=cut

sub letsmt_request_result {
    my $method = shift;

    my $res = letsmt_request( $method, @_ );
    return wantarray
        ? ( $res->is_success, $res->decoded_content, $res->code, $res )
        : ($method eq 'GET')
            ? $res->decoded_content
            : $res->is_success;
}


=head2 C<verbose>

 WebService::verbose

Toggle verbose output (via User Agent's show_progress attribute).
Default: off.

=cut

sub verbose {
    $VERBOSE = (not $VERBOSE);
}


=head2 C<build_server_address>

 $url = build_server_address ($server)

=cut

sub build_server_address {
    my $server = shift;
    return 'https://' . $server . ':' . $ENV{LETSMTPORT} . '/ws';
}


# ------------------------------------------------------------------------------
# STORAGE
# ------------------------------------------------------------------------------

=head1 FUNCTIONS - Storage

=head2 C<put_file_request>

 $success = put_file_request ($make_url_ref, $resource, $file)

Upload C<$file> to the repository location corresponding to C<$resource>.
C<$make_url_ref> is a code reference for making an appropriate URL for the HTTP request.

=cut

sub put_file_request {
    my $make_url_ref = shift;
    my $resource     = shift;
    my $file         = shift;

    # Open the local file in binary mode.
    open( my $fh, '<', $file )  # || get_logger(__PACKAGE__)->error("Unable to open $file");
        or raise( 8, "Unable to open $file", 'error' );
    binmode $fh;

    # Create an anonymous read function.
    my $read_func = sub {
        read( $fh, my $buf, 65536 );
        return $buf;
    };

    # Send the request.
    my ($url, $server) = $make_url_ref->( $resource, @_ );
    my $res = &user_agent($server)->request(
        new HTTP::Request(
            'PUT',             $url,
            new HTTP::Headers, $read_func
        )
    );

    # Close the file.
    close $fh
        or raise( 8, "Unable to close $file", 'error' );

    return wantarray
        ? ( $res->is_success, $res->decoded_content, $res )
        : $res->is_success;
}


=head2 C<post_file_request>

 $success = post_file_request ($make_url_ref, $resource, $file, %payload)

Uploads C<$file> to the repository location corresponding to C<$resource>.
C<$make_url_ref> is a code reference for making an appropriate URL for the HTTP request.

=cut

sub post_file_request {
    my $make_url_ref = shift;
    my $resource     = shift;
    my $file         = shift;

    #
    # Send the request.
    #
    my ($url, $server) = $make_url_ref->( $resource, @_ );
    my $res = &user_agent($server)->request(
        POST $url, ## using the HTOOP::Request::Common interface
        Content_Type => 'form-data',
        Content      => [ payload => ["$file"], ]
    );

    return wantarray
        ? ( $res->is_success, $res->decoded_content, $res )
        : $res->is_success;
}


=head2 C<get_resource_request>

 $object = get_resource_request ($make_url_ref, $resource, %payload)

Download a resource from the repository.
C<$make_url_ref> is a code reference for making an appropriate URL for the HTTP request.

Returns true or false.
A true return value signals that the submitted resource object
can be used to access a local copy of the corresponding repository file.

=cut

sub get_resource_request {
    my $make_url_ref = shift;
    my $resource     = shift;
    my %params       = @_;

    # Determine whether we are downloading an archive or not.
    my $download_archive = ! (
           defined $params{archive}
        && $params{archive} =~ /^no$/i
    );

    # Determine the actual name of the downloaded file.
    my $target_file = $resource->local_path;
    my $target_dir = dirname($target_file);
    $target_file .= $archive_suffix  if ( $download_archive );
    File::Path::make_path($target_dir);

    # Send the request.
    my ($url, $server) = $make_url_ref->( $resource, action => 'download', @_ );
    my $res = &user_agent($server)->request(
        new HTTP::Request( 'GET', $url ),
        $target_file
    );

    # If we successfully downloaded an archive: unpack it.
    # (but if param{archive} is given --> keep it packed)
    unless ( defined $params{archive} ) {
        if ( $res->is_success && $download_archive ) {
            my $success = &run_cmd(
                'unzip','-qq','-o','-d',
                dirname( $resource->local_path ),
                $target_file,
            );
            return 0 unless ($success);
            unlink($target_file);
        }
    }
    return wantarray
        ? ( $res->is_success, $res->decoded_content, $res )
        : $res->is_success;
}


#----------------------------------------------------------------------
# STORAGE API
#----------------------------------------------------------------------

=head1 FUNCTIONS - Storage API

=head2 C<storage_url>

 $url = storage_url ($resource, %payload)

Create a url to the storage of C<$resource>.
If no C<uid> parameter is supplied, the C<< $resource->user >> is used.

=cut

sub storage_url {
    my $resource = shift;
    my %para     = @_;
    $para{uid} = $resource->user if ( !$para{uid} );
    my $server = $resource->get_server( $para{uid} );
    my $url = new URI(
        join( '/', $server, 'storage', $resource->storage_path )
    );
    $url->query_form(%para);

    # $url->query_form( uid => $resource->user, @_ );
    return wantarray
        ? ($url, $server)
        : $url;
}


=head2 C<get> | C<put> | C<post> | C<del>

 $data = get($resource, uid C<< => >> requesting_user)  # Force requesting_user as uid
 put($resource->path_down, gid => user)                 # Ensure the resource path exists
 # etc.

Issue an HTTP request to the storage of the resource.

C<get> returns an C<HTTP::Response> object,
the others return C<true> or C<false> reflecting the success of the request.

=cut

sub get {
    my $fun = \&storage_url;
    return &letsmt_request_result( 'GET', \&storage_url, @_ );
}


sub put {
    return &letsmt_request_result( 'PUT', \&storage_url, @_ );
}


sub post {
    return &letsmt_request_result( 'POST', \&storage_url, @_ );
}


sub del {
    return &letsmt_request_result( 'DELETE', \&storage_url, @_ );
}


=head2 C<put_resource>

 $success = put_resource ($resource, %payload)

Uploads a resource to the repository using a PUT request.

=cut

sub put_resource {
    my $resource = shift;
    return &put_file( $resource, $resource->local_path, @_ );
}


=head2 C<put_file>

 $success = put_file ($resource, $file)

Upload C<$file> to the repository location corresponding to C<$resource>.

=cut

sub put_file {
    return &put_file_request( \&storage_url, @_ );
}


=head2 C<post_file>

 $success = post_file ($resource, $file)

Upload C<$file> to the repository location corresponding to C<$resource>.

=cut

sub post_file {
    return &post_file_request( \&storage_url, @_ );
}


=head2 C<get_resource>

 $success = get_resource ($resource)

Download a resource from the repository.

Returns true or false.
A true return value signals that the submitted resource object
can be used to access a local copy of the corresponding repository file.

=cut

sub get_resource {
    return &get_resource_request( \&storage_url, @_ );
}


=head2 C<copy>

 $success = copy ($resource, $uid[, $dest[, $revision]])

Make a copy of an entire branch specified by C<resource>.

The name of the destination branch is C<$dest>, or C<$uid> if no C<$dest> is given.
C<$revision> is optional.
C<$uid> needs to have read permissions for the resource!

=cut

sub copy {
    my $resource   = shift;
    my $uid        = shift;
    my $dest       = shift || $uid;
    my ($revision) = @_;

    my %para = ( action => 'copy', uid => $uid, dest => $dest );
    $para{rev} = $revision if ($revision);

    return &letsmt_request_result( 'POST', \&storage_url, $resource, %para );
}


=head2 C<fetch>

 $local_path = fetch($path, $user, $local_dir)

Fetch a resource from the repository using the given path and user.
Returns the local path to the resource if fetching succeeds.

=cut

sub fetch {
    my ( $path, $user, $local_dir ) = @_;
    my $resource = LetsMT::Resource::make_from_path( $path, $user, $local_dir );
    if ($resource) {
        &get_resource($resource) || return undef;
        return $resource->local_path();
    }
    return undef;
}


=head2 C<list>

 @list = list ($slot, $branch, $path)

=cut

sub list {
    my ( $slot, $branch, $path ) = @_;
    my $resource = LetsMT::Resource::make( $slot, $branch, $path );
    return &get($resource);
}


=head2 C<resource_exists>

 $exists = resource_exists ($resource)

Returns 1 if the given resource exists in the repository.

=cut

sub resource_exists {
    my $resource = shift;
    my $xml      = scalar &get($resource);
    return 0 if ( not $xml );

    my $list = XMLin( $xml, KeyAttr => ['name'] );
    if ( ref($list) eq 'HASH' ) {
        if ( ref( $$list{list} ) eq 'HASH' ) {
            return 1 if ( ref( $$list{list}{entry} ) eq 'HASH' );
        }
    }
    return 0;
}


# ------------------------------------------------------------------------------
# METADATA
# ------------------------------------------------------------------------------

=head1 FUNCTIONS - Metadata

=head2 C<meta_url>

 $url = meta_url ($resource, %payload)

Produce an url to the meta data of C<$resource>.

=cut

sub meta_url {
    my $resource = shift;
    my %para     = @_;
    $para{uid} = $resource->user if ( !$para{uid} );
    my $server = $ENV{META_DB_HOST};
    my $url = new URI(
        join( '/',
            &build_server_address($server), 'metadata',
            $resource->storage_path
        )
    );
    $url->query_form(%para);

    return wantarray
        ? ($url, $server)
        : $url;
}


=head2 C<get_meta> | C<put_meta> | C<post_meta> | C<del_meta>

 $response = get_meta ($resource, %payload)
 $success = post_meta ($resource, %payload)
 # etc.

Issue the corresponding HTTP requests to the meta data of C<$resource>.

The function C<get_meta> returns an C<HTTP::Response> object,
and the others return C<true> or C<false> reflecting the success of the request.

=cut

sub get_meta {
    return &letsmt_request_result( 'GET', \&meta_url, @_ );
}

sub put_meta {
    return &letsmt_request_result( 'PUT', \&meta_url, @_ );
}

sub post_meta {
    return &letsmt_request_result( 'POST', \&meta_url, @_ );
}

sub del_meta {
    return &letsmt_request_result( 'DELETE', \&meta_url, @_ );
}


=head2 C<search_meta>

 @result = search_meta (%payload)

=cut

sub search_meta {
    my $server = $ENV{META_DB_HOST};
    my $url = new URI(
        join( '/', &build_server_address($server), 'metadata' )
    );
    $url->query_form(@_);
    return &request_result( 'GET', $url );
}


=head2 C<list_meta>

 @list = list_meta ($slot, $branch, $path)

=cut

sub list_meta {
    my ( $slot, $branch, $path ) = @_;
    my $resource = LetsMT::Resource::make( $slot, $branch, $path );
    return &get_meta($resource);
}


# ------------------------------------------------------------------------------
# GROUPS
# ------------------------------------------------------------------------------

=head1 FUNCTIONS - Groups

=head2 C<group_url>

 $url = group_url ($gid, $user, $uid, %payload)

Produce an url to a user (C<$user>) in a group (C<$gid>).
The URL points to the group only if C<$user> is left out.
C<$uid> is the effective user that will perform the action.
C<$gid> will be used if C<$uid> is not specified.

=cut

sub group_url {
    my $gid    = shift;
    my $user   = shift;
    my $uid    = shift || $user || $gid; # effective user (owner of the group)
    my $server = $ENV{GROUP_DB_HOST};
    my $path   = join( '/',
        &build_server_address($server), 'group', $gid
    );
    $path .= '/' . $user if ($user);

    my $url = new URI( $path );
    $url->query_form( uid => $uid, @_ );
    return wantarray
        ? ($url, $server)
        : $url;
}


=head2 C<get_group> | C<put_group> | C<post_group> | C<del_group>

 $group = get_group ($gid, $uid, $owner, %payload)
 #etc.

Issues the corresponding HTTP requests to the user C<$uid> in the group C<$gid>.
The function C<get_group> returns an C<HTTP::Response> object,
and the others return C<true> or C<false> reflecting the success of the request.

=cut

sub get_group {
    return &letsmt_request_result( 'GET', \&group_url, @_ );
}

sub put_group {
    return &letsmt_request_result( 'PUT', \&group_url, @_ );
}

sub post_group {
    return &letsmt_request_result( 'POST', \&group_url, @_ );
}

sub del_group {
    return &letsmt_request_result( 'DELETE', \&group_url, @_ );
}


=head2 C<user_exists>

 $exists = user_exists ($user, $group, $owner)

=cut

sub user_exists {
    my $user  = shift;
    my $group = shift || $user;
    my $owner = shift || $user;

    my $xml = scalar &get_group( $group, $user, $owner );

    # my $xml   = $self->list( $group, $user );
    return 0 if ( not $xml );
    my $list = XMLin( $xml, ForceArray => ['user'] );
    if ( ref($list) eq 'HASH' ) {
        if ( ref( $$list{status} ) eq 'HASH' ) {
            if ( ref( $$list{status}{group} ) eq 'HASH' ) {
                if ( ref( $$list{status}{group}{user} ) eq 'HASH' ) {
                    return 1 if ( exists $$list{status}{group}{user}{$user} );
                }
            }
        }
    }
    return 0;
}


# ----------------------------------------------------------------------------
# ACCESS
# ----------------------------------------------------------------------------

=head1 FUNCTIONS - Access Permissions

=head2 C<access_url>

 $url = access_url ($resource, %payload)

Produce a URL to the slot for setting access permissions.

=cut

# TODO: only slot level can be addressed and branch is always 'uid', should be more flexible
sub access_url {
    my $resource = shift;
    my %para     = @_;

    $para{uid}    = $resource->user if ( !$para{uid} );
    $para{slot}   = $resource->slot if ( !$para{slot} );
    $para{branch} = $resource->user if ( !$para{branch} );

    my $server = $resource->get_server( $para{uid} );

    my $url = new URI(
        join( '/',
            $server, 'access',
            $para{slot}, $para{branch} )
    );

    if ( $para{gid} ) {
        $url->query_form( uid => $para{uid}, gid => $para{gid}, @_ );
    }
    else {
        $url->query_form( uid => $para{uid}, @_ );
    }
    return wantarray
        ? ($url, $server)
        : $url;
}


=head2 C<get_access> | C<put_access>

 $access = get_access ($gid, $uid)

Issue the corresponding HTTP requests to the user C<$uid> in the group C<$gid>.
The function C<get_access> returns an C<HTTP::Response> object,
C<put_access> returns C<true> or C<false> reflecting the success of the request.

=cut

sub get_access {
    return &letsmt_request_result( 'GET', \&access_url, @_ );
}

sub put_access {
    return &letsmt_request_result( 'PUT', \&access_url, @_ );
}


# ----------------------------------------------------------------------------
# ADMIN
# ----------------------------------------------------------------------------

=head1 FUNCTIONS - Administration

=head2 C<admin_url>

 $url = admin_url ($resource, %payload)

=cut

sub admin_url {
    my $resource = shift;
    my %para     = @_;

    my ($url, $server);
    if ( defined $resource ) {
        $para{uid} = $resource->user if ( !$para{uid} );
        $server    = $resource->get_server( $para{uid} );
        $url       = new URI(
            join( '/', $server, 'admin', $resource->letsmt_path )
        );
    }
    else {
        $server = $ENV{LETSMT_URL};
        $url    = new URI( join( '/', $server, 'admin' ) );
    }

    $url->query_form(%para);

    return wantarray
        ? ($url, $server)
        : $url;
}

sub get_admin {
    return &letsmt_request_result( 'GET', \&admin_url, @_ );
}

sub post_admin {
    return &letsmt_request_result( 'POST', \&admin_url, @_ );
}


# ------------------------------------------------------------------------------
# JOB
# ------------------------------------------------------------------------------

=head1 FUNCTIONS - Jobs

=head2 C<job_url>

 $url = job_url ($resource, %payload)

Produce an url to the job of C<$resource>.

=cut

sub job_url {
    my $resource = shift;
    my %para     = @_;

    $para{uid} = $resource->user if ( !$para{uid} );
    my $server = $resource->get_server( $para{uid} );
    my $url    = new URI(
        join( '/', $server, 'job', $resource->storage_path )
    );
    $url->query_form(%para);

    #    $url->query_form( uid => $resource->user, @_ );
    return wantarray
        ? ($url, $server)
        : $url;
}


=head2 C<get_job> | C<put_job> | C<post_job> | C<del_job>

 $job = get_job ($resource, %payload)
 # etc.

Issues the corresponding HTTP requests to the job of C<$resource>. The
C<get_job> method return an C<HTTP::Response> object, and the others return
C<true> or C<false> reflecting the success of the request.

=cut

sub get_job {
    return &letsmt_request_result( 'GET', \&job_url, @_ );
}

sub put_job {
    return &letsmt_request_result( 'PUT', \&job_url, @_ );
}

sub post_job {
    return &letsmt_request_result( 'POST', \&job_url, @_ );
}

sub del_job {
    return &letsmt_request_result( 'DELETE', \&job_url, @_ );
}


# -----------------------------------------------------------------------------
# LETSMT API
# -----------------------------------------------------------------------------

=head1 "HIGH-LEVEL" LETSMT API

The following "high-level" functions are obsolescent.
They remain for the time being mostly for the sake of backward compatibility.

=head2 C<letsmt_url>

letsmt_url ($resource)

Create the high-level url of C<$resource>.
If no C<uid> parameter is supplied, the C<$resource-E<gt>user> is used.

=cut

sub letsmt_url {
    my $resource = shift;
    my %para     = @_;

    $para{uid} = $resource->user unless ($para{uid});
    my $server = $resource->get_server( $para{uid} );
    my $url = new URI(
        join( '/', $server, 'letsmt', $resource->letsmt_path )
    );
    $url->query_form(%para);

    # $url->query_form( uid => $resource->user, @_ );
    return wantarray
        ? ($url, $server)
        : $url;
}


=head2 The high-level API (letsmt)

The high-level LetsMT API provides the same services as the low-level API but uses
different resource URLs and triggers some additional internal processes.
The sub-routines provided here are used in the same way as the low-level functions.

 get_letsmt ($resource)
 put_letsmt ($resource)
 post_letsmt ($resource)
 del_letsmt ($resource)
 put_letsmt_resource ($resource)
 put_letsmt_file ($resource, $file)
 get_letsmt_resource ($resource)

=cut

sub get_letsmt {
    return &letsmt_request_result( 'GET', \&letsmt_url, @_ );
}

sub put_letsmt {
    return &letsmt_request_result( 'PUT', \&letsmt_url, @_ );
}

sub post_letsmt {
    return &letsmt_request_result( 'POST', \&letsmt_url, @_ );
}

sub del_letsmt {
    return &letsmt_request_result( 'DELETE', \&letsmt_url, @_ );
}

sub put_letsmt_resource {
    my $resource = shift;
    return &put_letsmt_file( $resource, $resource->local_path, @_ );
}

sub put_letsmt_file {
    return &put_file_request( \&letsmt_url, @_ );
}

sub get_letsmt_resource {
    return &get_resource_request( \&letsmt_url, @_ );
}


=head2 C<fetch_letsmt ($path, $user, $local_dir)>

Fetch a resource from the repository using the given letsmt-path and user.
Returns the local path to the resource.

=cut

sub fetch_letsmt {
    my ( $path, $user, $local_dir ) = @_;
    my $resource = LetsMT::Resource::make_from_letsmt_path(
        $path, $user, $local_dir
    );
    return $resource->local_dir();
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
