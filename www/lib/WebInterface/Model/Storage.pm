package WebInterface::Model::Storage;
use strict;
use warnings;
use v5.10;

use open qw(:std :utf8);

use Encode qw/is_utf8 decode encode/;
use File::Temp qw/ tempfile tempdir /;
use File::Basename;
use File::Copy;

use Mojo::Asset::File;
use base qw/Mojo::Base/;

###############################################################################
# Get
###############################################################################
sub get {
    my ( $self, $slot, $branch, $path, $user, $rev ) = @_;

    # $self->logger->debug( 'slot   '. $slot );
    # $self->logger->debug( 'branch '. $branch );
    # $self->logger->debug( 'path   '. $path );
    # $self->logger->debug( 'user   '. $user);

    my $resource =
      LetsMT::Resource::make_from_path( join( '/', $slot, $branch, $path ), );

    my $list_result = LetsMT::WebService::get(
        $resource,
        uid => $user || 'mojo',
        rev => $rev  || 'HEAD',
    );

    return encode( 'utf8', $list_result );
}

###############################################################################
# Get from path
###############################################################################
sub get_from_path {
    my ( $self, $path, $user, $rev ) = @_;

    my $resource = LetsMT::Resource::make_from_path( 'storage/' . $path );

    my $list_result = LetsMT::WebService::get(
        $resource,
        uid => $user || 'mojo',
        rev => $rev,
#        rev => $rev  || 'HEAD',
    );

    return encode( 'utf8', $list_result );
}

###############################################################################
# Put
###############################################################################
sub put {

}

###############################################################################
# Delete
###############################################################################
sub delete {
    my ( $self, $slot, $branch, $path, $user ) = @_;

    my $resource =
      LetsMT::Resource::make( $slot, $branch, $path );

    my $delete_result = LetsMT::WebService::del( $resource, uid => $user );

    return $delete_result;
}

###############################################################################
# Cat
###############################################################################
sub cat {
    my ( $self, $slot, $branch, $path, $user, $from, $to, $rev ) = @_;

    my $resource =
      LetsMT::Resource::make_from_path( join( '/', $slot, $branch, $path ) );

    my $cat_result = LetsMT::WebService::get(
        $resource,
        action => 'cat',
        from   => $from,
        to     => $to ? ( $to =~ m/end/i ? '' : $to ) : '',
        uid    => $user,
        rev => $rev || 'HEAD',
    );

    my $dom     = Mojo::DOM->new($cat_result);
    my $content = $dom->at('entry')->all_text(0);

    return $content;
}

###############################################################################
# Download
###############################################################################
sub download {
    my ( $self, $slot, $branch, $path, $user ) = @_;

    #$self->logger->debug( 'slot   '. $slot );
    #$self->logger->debug( 'branch '. $branch );
    #$self->logger->debug( 'path   '. $path);
    #$self->logger->debug( 'user   '. $user);

    my $rand       = int( rand(89999999) ) + 10000000;
    my $local_path = $ENV{UPLOADDIR} . '/mojo_download_' . $rand;

    #$self->logger->debug( 'local_path:'.$local_path );

    my $resource =
      LetsMT::Resource::make( $slot, $branch, $path, $local_path, );

    my $result = LetsMT::WebService::get_resource(
        $resource,
        uid => $user || 'mojo',
        action  => 'download',
        archive => 'yes',
    );

    if ($result) {
        return $local_path . '/' . $path . '.zip';
    }
    else {
        return 0;
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
