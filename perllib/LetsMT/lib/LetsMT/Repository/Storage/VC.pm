package LetsMT::Repository::Storage::VC;

=head1 NAME

LetsMT::Repository::VC - storage backend for a version controlled file system with a working copy in a compressed file system

=head1 DESCRIPTION

This storage backend keeps a working copy (using the compressed filesystem backend) but also handles a version-controlled repository using AnyVC

=cut

use strict;
use parent 'LetsMT::Repository::Storage::Compressed';

use LetsMT;
use LetsMT::Repository::Storage::Compressed;
use LetsMT::Repository::Storage::AnyVC;

use Cwd;
use File::Basename;

=head1 CONSTRUCTOR

 $storage = new LetsMT::Repository::Storage::VC (%params);

=cut

sub new {
    my $class = shift;
    my %args  = @_;

    # create the compressed files system backend (parent class)
    my $self = $class->SUPER::new(%args);

    # create the versione controlled backend
    $self->{VC} = new LetsMT::Repository::Storage::AnyVC(%args);

    return bless $self, $class;
}


=head1 METHODS

=head2 C<init>

 $storage->init ($path)

Initialize a new repository.

Returns: true (an exception is raised on failure).

=cut

sub init {
    my $self = shift;
    my ($slot) = @_;

    # initialize the versione controlled backend
    $self->{VC}->init(@_);


    # initialize the working copy by checking out an empty root dir
    $self->{VC}->checkout(
        repos => $slot,
        rev   => "HEAD",
        trg   => $self->{partition}.'/'.$slot,
        flags => '--depth empty'
    );


    # initialize the compressed files system backend (parent class)
    return $self->SUPER::init(@_);
}




sub list {
    my $self = shift;
    my %params = @_;

    # if the last path-element == 'status':
    # --> return status of the parent directory
    if ($params{dir}=~s/(\A|\/)status$//){
	my $path = join( '/',
			 $self->{partition},
			 $params{repos},
			 $params{dir});
	my $pwd = getcwd();
	chdir($path);
	my $xml = $self->{VC}->status( %params );
	chdir($pwd);
	return $xml;
    }

    my $list = $self->SUPER::list(@_);
    my %info = $self->{VC}->info(@_);
    $list =~s/(<commit revision=\")\"/$1$info{Revision}\"/;
    return $list;
}




=head2 C<mkdir>

 $storage->mkdir ($repos, $branch, $user, $dir)

Make a new directory

Returns: true if directory already exists, or creation went well.
An exception is raised on creation failure.

=cut



sub mkdir {
    my $self = shift;
    my ( $repos, $branch, $user, $dir ) = @_;

    # if the last path-element == 'commit':
    # --> commit all changes in the parent dir!
    if ( $dir eq 'commit' ){

	# try to do it in the background using fork ....
	my $pid = fork();
	if ((not defined $pid) || ($pid==0) ) {
	    ## commit all changes in the entire branch
	    my $ret = $self->_commit_changes( $repos, $branch, $user );
	    exit(0) if ($pid ==0);   # exit if this was a child process
	    return $ret;             # otherwise: return $ret
	} 
	return 1;                    # the parent process just returns ....
    }

    $self->_goto_root( $repos );
    $self->SUPER::mkdir( $repos, $branch, $user, $dir );
    $self->{VC}->add_file( $user, $branch.'/'.$dir );
    $self->_come_back();

    return 1;
}




# internal method: commit all changes from the working copy

sub _commit_changes {
    my $self = shift;
    my ( $repos, $branch, $user ) = @_;
    $self->_goto_root( $repos );
    # make sure everything is added
    $self->{VC}->add_file( $user, $branch ); 
    # commit all changes to the central repository
    my $ret=$self->{VC}->commit($user, $branch, 'commit all changes');
    $self->_come_back();
    return $ret;
}



sub cat {
    my $self = shift;
    my ($range, $path, $uid, $rev) = @_;
    if (defined $rev && $rev ne 'HEAD'){
	return $self->{VC}->cat(@_);
    }
    return $self->SUPER::cat(@_);
}



sub copy {
    my $self = shift;
    my ( $user, $slot, $src, $trg ) = @_;

    if ($self->{VC}->is_path( repos => $slot, branch => $src )){
      $self->{VC}->copy(@_);
    }
    return $self->SUPER::copy(@_);
}


### TODO: shouldn't we use 'svn delete' on the working copy (+ commit?)

sub remove {
    my $self = shift;
    my %params = @_;

    # remove from repositorium (if it has been committed)
    if ($self->{VC}->is_path(@_)){
	$self->{VC}->remove(@_);
    }

    # remove working copy
    return $self->SUPER::remove(@_);
}

sub export {
    my $self  = shift;
    my %params = @_;

    if (defined $params{rev} && $params{rev} ne 'HEAD'){
	return $self->{VC}->export(@_);
    }
    return $self->SUPER::export(@_);
}


=head2 C<revisions>

 %revisions = $storage->revisions (@path_elements)

Returns: a list of revisions for a given resource

=cut

sub revisions{
    my $self = shift;

    my %revisions = $self->{VC}->revisions(@_);
    $revisions{999999999} = localtime;
    return %revisions;
}


# go to the root of the working copy

sub _goto_root{
    $_[0]->{_pwd_}  = getcwd();
    chdir( join( '/', $_[0]->{partition}, $_[1] ) );
}

# come back to previously saved dir

sub _come_back{
    chdir($_[0]->{_pwd_}) if (defined $_[0]->{_pwd});
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
