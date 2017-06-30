package LetsMT::Repository::Storage::SVNServer;

=head1 NAME

LetsMT::Repository::SVNServer - storage backend for access to remote Subversion

=head1 DESCRIPTION

This class is a child of 
L<LetsMT::Repository::Storage::SVNLocal|LetsMT::Repository::Storage::SVNLocal>
and adds some server capabilities to it.
Most documentation is found in that class.

=cut

use strict;
use parent 'LetsMT::Repository::Storage::SVNLocal';

use open qw(:std :utf8);

use LetsMT;
use LetsMT::Repository::Storage::SVNLocal;

use LetsMT::Tools;
use LetsMT::Repository::Err;

use Log::Log4perl qw(get_logger :levels);
use File::Copy;


our $SVN_USER     = $LetsMT::SVN_USER;
our $SVN_PASSWORD = $LetsMT::SVN_PASSWORD;

our $SVN      = "svn --username='www-data' --password='$SVN_PASSWORD'";
our $SVNADMIN = 'svnadmin';

# for using run_cmd: it's better to separate executable and its arguments!

our $SVN_CMD  = 'svn';
our @SVN_PARA = (
    '--non-interactive',
    '--username' => 'www-data',
    '--password' => $SVN_PASSWORD
);

=head1 CONSTRUCTOR

 $storage = new LetsMT::Repository::Storage::SVNServer (%params);

=cut

sub new {
    my $class = shift;
    my %self  = @_;

    $self{SVN}      = $self{SVN}      || $SVN;
    $self{SVNADMIN} = $self{SVNADMIN} || $SVNADMIN;
    $self{SVN_CMD}  = $self{SVN_CMD}  || $SVN_CMD;
    $self{SVN_PARA} = $self{SVN_PARA} || \@SVN_PARA;

    $self{protocol}  = 'svn:/';
    $self{host}      = 'localhost';
    $self{partition} = $ENV{LETSMTDISKROOT} || '/var/lib';

    $self{base_url} = join( '/',
        $self{protocol},
        $self{host}
    );

    bless \%self, $class;
    return \%self;
}


=head1 METHODS

=head2 C<init>

 $storage->init ($path)

Initialize a new subversion repository.

Returns: true (an exception is raised on failure).

=cut

sub init {
    my $class = shift;
    my ( $slot, $user ) = @_;

    # diskpath = partition/slot
    my $path = join( '/',
        $class->{partition},
        $slot
    );

    # 2 --> slot exists already!
    return 2 if ($class->SUPER::init(@_) == 2);

    # fail if the path does not exist
    unless ( -d $path ) {
        raise( 8, "cannot create slot '$slot'" );
    }

    # copy svn repository configuration file into new repository,
    # needed for svn:// access

    File::Copy::copy(
        '/usr/local/etc/repository/svnserve.conf',
        "$path/conf/svnserve.conf"
    ) or raise( 8, "copy of svnserv.conf to '$path' failed" );
    chmod 0440, "$path/conf/svnserve.conf";

    # add user
    $class->add_user( $slot, 'www-data' );
    $class->add_user( $slot, $user );
    return 1;
}


=head2 C<add_user>

 $storage->add_user ($slot, $user)

Add a user to the repository.

Returns: true (an exception is raised on failure).

=cut

sub add_user {
    my ( $class, $slot, $user ) = @_;

    # diskpath = partition/slot
    my $path = join( '/',
        $class->{partition}, $slot
    );

    chmod 0640, "$path/conf/passwd";
    open F, '>>', "$path/conf/passwd"
        or raise( 8, "cannot write to '$path/conf/passwd'" );
    flock( F, 2 )
        or raise( 8, "cannot lock '$path/conf/passwd'" );
    print F "$user = $SVN_PASSWORD\n";
    close F;
    chmod 0440, "$path/conf/passwd";
}


=head2 C<mkdir>

 $storage->mkdir ($repos, $branch, $user, $dir)

A wrapper around C<svn mkdir>.

Returns: true if directory already exists, or creation went well.
An exception is raised on creation failure.

=cut

sub mkdir {
    my $class = shift;
    my ( $repos, $branch, $user, $dir ) = @_;

    # branch & dir exist ---> just do standard mkdir
    if ( $branch && $dir ) {
        return $class->SUPER::mkdir(@_);
    }

    # otherwise: check if the branch already exists
    if ( $class->is_path(
            repos  => $repos,
            branch => $branch,
            dir    => $dir
        )
    ) {
        return 1;
    }

    # if not: add the creating user to enable write permissions
    # and make the directory
    $class->add_user( $repos, $user );
    return $class->SUPER::mkdir(@_);
}


=head2 C<copy>

 $storage->copy ($user, $slot, $source, $target)

A wrapper around C<svn copy>.

Returns: true (an exception is raised on failure).

=cut

sub copy {
    my $class = shift;
    my ( $user, $slot ) = @_;
    $class->add_user( $slot, $user );
    return $class->SUPER::copy(@_);
}


=head1 INTERNAL METHOD

=head2 C<_cleanup_listing>

 $listing = $storage->_cleanup_listing ($listing, $slotobject)

A simplistic way to cleanup absolute paths from the svn listings.
Does things slightly differently from the parent class.

=cut

sub _cleanup_listing {
    my $self = shift;
    my ($contents) = @_;
    $contents =~ s/svn\:\/\/localhost//s;
    return $contents;
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