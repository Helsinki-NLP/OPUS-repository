package LetsMT::Repository::Storage::Git;

=head1 NAME

LetsMT::Repository::Git - storage backend using Git

=head1 DESCRIPTION

This class is a child of 
L<LetsMT::Repository::Storage::FileSystem|LetsMT::Repository::Storage::FileSystem> but adds git-specific commands to update a local git reposoitory

=cut

use strict;
use parent 'LetsMT::Repository::Storage::FileSystem';

use open qw(:std :utf8);
use Encode qw(decode decode_utf8 is_utf8);

use LetsMT;
use LetsMT::Repository::Storage::FileSystem;

use LetsMT::Tools;
use LetsMT::Repository::Err;

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use File::Basename qw/ basename dirname /;
use File::Copy;
use File::Temp qw(tempfile tempdir);
use File::Path;
use File::Touch;

use Log::Log4perl qw(get_logger :levels);
use Data::Dumper;
use Cwd;


our $GITHOME = $ENV{LETSMTDISKROOT} || '/var/lib';
$GITHOME .= '/.githome';


=head1 METHODS

=head2 C<init>

 $storage->init ($slot, $user, $base, $githome)

Initialize a new subversion repository.

Returns: true (an exception is raised on failure).

=cut

sub init {
    my $self = shift;
    my $slot = shift || return 0;
    my $user = shift || return 0;
    my $base = shift || 'master';
    my $githome = shift || $GITHOME;

    ## path to master git
    my $gitpath = join( '/', ( $githome, $slot ) );

    ## create the git master repository
    unless (-d $gitpath.'/.git'){
	get_logger(__PACKAGE__)->info("initialize master git at $gitpath");
	mkdir($githome) unless (-d $githome);
	my ( $success, $ret, $out, $err ) = run_cmd(
	    'git',
	    'init',
	    $gitpath
	    );
	unless ($success){
	    # my @err_lines = <$err>;
	    raise( 8, "cannot create git-repo $gitpath: " . $err );
	}
    }
    return $self->_clone( $slot, $user, $base );
}


## make a clone of the master repository and create a new branch (=user)
## (optional: use a given $branch to start the new user branch)

sub _clone{
    my $self = shift;
    my $slot = shift || return 0;
    my $user = shift || return 0;
    my $branch = shift || 'master';
    my $githome = shift || $GITHOME;

    ## path to master git
    my $mastergit = join( '/', ( $githome, $slot ) );

    ## path to local copy with user branch
    my $localgit = join( '/', ( $self->{partition}, $slot, $user ) );

    get_logger(__PACKAGE__)->info("git clone $mastergit $localgit");
    my ( $success, $ret, $out, $err ) = 
	&run_cmd( 'git', 'clone', $mastergit, $localgit );
    unless ($success){
	# my @err_lines = <$err>;
	raise( 8, "cannot clone git-repo $mastergit to $localgit: " . $err );
    }

    my $pwd = getcwd();
    chdir($localgit);

    ## switch to given branch to start with
    &run_cmd( 'git', 'checkout', $branch );

    ## create new branch
    ( $success, $ret, $out, $err ) = 
	&run_cmd( 'git', 'checkout', '-b', $user );

    chdir($pwd);
    unless ($success){
	# my @err_lines = <$err>;
	raise( 8, "cannot create branch $user in git-repo $localgit: " . $err );
    }

    ## create standard dirs xml and uploads (trick to make the git non-empty!)
    # $self->mkdir( $slot, $user, $user, 'xml' );
    # $self->mkdir( $slot, $user, $user, 'uploads' );

    return $success;
}


## add and commit a file or subdir to a git repository
##
## - slot ...... name of the repo
## - user ...... user name (also name of the branch)
## - path ...... relative path to new file/subdir
## - message ... optional commit message

sub _add_file{
    my ( $self, $slot, $user, $path ) = @_;

    get_logger(__PACKAGE__)->debug("git: add file $path to repo $slot/$user");

    ## path to local copy with user branch
    my $gitpath = join( '/', ( $self->{partition}, $slot, $user ) );

    my $pwd = getcwd();
    chdir($gitpath);
    my $success = &run_cmd( 'git', 'add', $path );
    chdir($pwd);

    # $self->_commit( $slot, $user, 'add $path to repository' );
    return $success;
}


## commit the latest changes and push to origin
## TODO: do we always have to push?

sub _commit{
    my ( $self, $slot, $user, $message ) = @_;
    $message = 'commit all changes' unless ($message);

    get_logger(__PACKAGE__)->debug("git: commit changes in $slot/$user");

    ## path to local copy with user branch
    my $gitpath = join( '/', ( $self->{partition}, $slot, $user ) );

    my $pwd = getcwd();
    chdir($gitpath);
    my $success = &run_cmd( 'git', 'commit', '-am', $message );
    if ($success){
	$success = &run_cmd( 'git', 'push', 'origin', $user );
    }
    chdir($pwd);

    return $success;
}


=head2 C<mkdir>

=cut

sub mkdir {
    my $self = shift;
    my ( $repos, $branch, $user, $dir ) = @_;

    my $path = join( '/', ( $self->{partition}, $repos, $branch, $dir ) );
    return 1 if (-d $path);

    get_logger(__PACKAGE__)->debug("git: mkdir $repos $branch $user $dir");

    ## no dir given: create a new repository branch
    unless ($dir){
	if ($user ne $branch){
	    return $self->init( $repos, $branch, $user );
	}
	return $self->init( $repos, $branch );
	# return $self->_clone( $repos, $branch, $user );
	# return 0 unless ($branch eq $user);
	# return $self->init( $repos, $branch );
    }

    if ( $self->SUPER::mkdir(@_) ){
	my $repohome = join( '/', $self->{partition}, $repos );
	my $file = join( '/', $dir, '.gitkeep' );
	touch( join( '/', $repohome, $branch, $file ) );
	$self->_add_file($repos, $user, $file);
	$self->_commit($repos, $user, 'added subdir $dir');
	return 1;
    }
    return 0;
}

=head2 C<copy>

 $storage->copy ($user, $slot, $source, $target)

copy an entire sub-tree

Returns: true (an exception is raised on failure).

=cut

sub copy {
    my $self = shift;
    my ( $user, $slot, $src, $trg ) = @_;

    my @srcpaths = split(/\//,$src);
    my @trgpaths = split(/\//,$trg);

    raise( 8, "copy is only implemented for a branch (src)" ) if ($#srcpaths);
    raise( 8, "copy is only implemented for a branch (dest)" ) if ($#trgpaths);

    ## make a new sub branch for the user $trg cloned from $src
    ## TODO: do we need to allow other types of copies?
    return $self->init( $slot, $trg, $src );
}


=head2 C<add>

 $storage->add ($user, $repos, $branch, $path, $file, $source)

Add a file (source) to a repository as C<$path>/C<$file>.

Returns: true (an exception is raised on failure).

=cut

sub add {
    my $self = shift;
    my ( $user, $repos, $branch, $dir, $file, $source ) = @_;


    # if ( $self->mkdir( $repos, $branch, $user, $dir ) ) {
    #     my $homedir  = join( '/', $self->{partition}, $repos );
    #     my $fullpath = join( '/', $self->{partition}, $repos, $branch, $dir, $file );
    #     my $relpath  = join( '/', $branch, $dir, $file );

    # 	get_logger(__PACKAGE__)->error("git: $source not found") unless (-e $source);
    # 	get_logger(__PACKAGE__)->info("git: move $source to $fullpath");
    #     move( $source, $fullpath ) || raise( 8, $! );


    if ( $self->SUPER::add(@_) ){
        my $path  = $dir ? join( '/', $dir, $file ) : $file;
	get_logger(__PACKAGE__)->info("git: add file $path to $repos/$branch");
	if ($self->_add_file( $repos, $branch, $path )){
	    return $self->_commit( $repos, $branch, 'added new file $file to $dir' );
	}
    }
    return 0;
}



=head2 C<remove>

 $storage->remove (
     repos => $repos,
     dir   => $dir,
     user  => $user,
 )

Remove objects from the repository using recursive git rm.

Returns: true (an exception is raised on failure)

=cut

sub remove {
    my $self  = shift;
    my %params = @_;
    map { $params{$_} = "" unless ( defined( $params{$_} ) ) }
        qw/ repos dir user /;


    ## (1) remove entire repository
    ## make a backup in .DELETED.
    ## TODO: don't we have to check whether the user is allowd to remove all branches?
    unless ( $params{dir} ){

	## path to master git
	my $mastergit = join( '/', ( $GITHOME, $params{repos} ) );
	my $localgit  = join( '/', ( $self->{partition}, $params{repos} ) );

	## THIS LOOKS QUITE DANGEROUS
	## TODO: MAKE SURE THAT NOTHING CAN GO WRONG HERE
	my $backup = join( '/', $self->{partition},'.DELETED.', $params{repos} );

	get_logger(__PACKAGE__)->debug("git: remove slot (backup at $backup)");

	if ( -d $backup ) {
	    if ($params{repos} && $params{repos}!~/^\./ && 
		$params{repos}!~/\.\.\// && $params{repos}!~/\s/){
		if ($GITHOME && $GITHOME!~/^\./ && $GITHOME!~/\.\.\//){
		    rmtree($backup)
			or raise( 8, "cannot remove $backup (" . $! . ')' );
		}
	    }
	}
	raise( 8, "cannot copy over to $backup") if ( -d $backup );

	get_logger(__PACKAGE__)->debug("git: move $mastergit to $backup)");
	unless ( -d dirname($backup) ) {
            mkdir( dirname($backup) )  or raise( 8, "mkdir ".dirname($backup) );
        }
	move( $mastergit, $backup ) || raise( 8, $! );

	## delete all branches
	## TODO: THIS LOOKS QUITE DANGEROUS ...
	## TODO: IS THIS ALL SAFE ENOUGH?
	get_logger(__PACKAGE__)->debug("git: remove $localgit");
	if ($params{repos} && $params{repos}!~/^\./ && 
	    $params{repos}!~/\.\.\// && $params{repos}!~/\s/){
	    if ($self->{partition} && $self->{partition}!~/^\./ 
		&& $self->{partition}!~/\.\.\//){
		rmtree($localgit)
		    or raise( 8, "cannot remove $localgit (" . $! . ')' );
		get_logger(__PACKAGE__)->debug("git: remove $localgit done)");
	    }
	}
	return 1;
    }

    my @paths = split(/\//,$params{dir});

    ## (2) remove entire branch
    ## TODO: do we need to check whether the user is allowed to do that? (but how?)
    ## (allow only if user=branch?))
    ## ---> just remove the local opy but do not remove the branch from the master copy
    ## alternative: git branch -d the_local_branch && git push origin :the_remote_branch
    ## new syntax in git 1.7: git push origin --delete the_remote_branch

    if ( $params{dir} eq $paths[0] ){
	$self->_commit( $params{repos}, $params{dir}, 
			"final commit before removing local copy" );
	return $self->SUPER::remove(@_);
    }


    ## (3) finally: remove subtree or file

    my $repohome = join( '/', $self->{partition}, $params{repos}, $params{user} );
    my $pwd = getcwd();
    chdir( $repohome );
    my $branch = shift ( @paths );
    my $path   = join( '/', @paths );
    my ($success,$ret,$out,$err) = &run_cmd( 'git', 'rm', '-r', $path );
    chdir($pwd);

    unless ($success) {
	# my @err_lines = <$err>;
	raise( 8, "cannot remove: " . $err );
    }

    $self->_commit( $params{repos}, $branch, "remove $path" );
    return $success;
}







=head2 C<commit>

 $storage->commit ($user, $repos, $path, $message )

Commit all changes in the given path with message $message.

Returns: ( $success, $return_code, $stdout, $stderr )

 $success = true if successful
 $return_code = return code of the system call
 $stdout = reference to stdout of the system call
 $stderr = reference to stderr of the system call

=cut


sub commit{
    my ( $self, $user, $repos, $dir, $message) = @_;
    return $self->( $repos, $user, $message );
}


sub revision{
    my ( $self, $user, $dir ) = @_;

    my $pwd = getcwd();
    chdir( dirname($dir) );
    my ($success,$ret,$out,$err) = &run_cmd( 'git',
					     'rev-parse',
					     '--short',
					     'HEAD' );
    chdir($pwd);

    if ($success){
	chomp($out);
	return $out;
    }
    return '';
}


=head2 C<revisions>

 %revisions = $storage->revisions (@path_elements)

Returns: a list of revisions for a given resource

=cut

sub revisions{
    my $self = shift;
    my $path = join( '/', $self->{partition}, @_ );

    my $pwd = getcwd();
    chdir( dirname($path) );
    my ($success,$ret,$out,$err) = &run_cmd( 'git',
					     'log',
					     '--pretty=format:"%h|%cd"' );
    chdir($pwd);

    my %revisions = ();
    if ($success){
	my @info = split(/\n/s,$out);
	foreach (@info){
	    s/^['"]//;s/['"]$//;
	    my ($rev,$date) = split(/\|/);
            $revisions{$rev} = $date;
	}
    }
    return %revisions;
}



=head2 C<list>

 $list = $storage->list( %params )

Parameters:

 repos
 dir
 branch
 revision

=cut

sub list {
    my $self  = shift;
    my %params = @_;
    map { $params{$_} = "" unless ( defined( $params{$_} ) ) }
        qw/ repos dir branch /;

    # need owner name to set 'author' attribute
    my $owner = length $params{branch} ? $params{branch}->owner() : 'unknown';
    my @paths = split(/\//,$params{dir});
    my $user = shift(@paths);
    my $path = join( '/', @paths );

    my $repohome = join( '/', $self->{partition}, $params{repos}, $user );
    my $path_to_display = join( '/', $params{repos}, $params{dir} );
    my $revision = $params{revision} || 'HEAD';

    if ($path){
	unless ( $self->_is_file( $repohome, $revision, $path )){
	    $path .= '/';
	}
    }
    else{
	## root dir
	$path = '--';
    }

    ## get listing from git
    my $pwd = getcwd();
    chdir( $repohome );
    get_logger(__PACKAGE__)->info("git: list $path in $repohome ($revision)");
    my ($success,$ret,$out,$err) = &run_cmd( 'git',
					     'ls-tree',
					     '-lz',
					     $revision,
					     $path );
    chdir($pwd);

    ## format output
    my $content = qq(<?xml version="1.0"?><list path="/$path_to_display">);
    if ($success){
	$out = decode( 'utf8', $out );
	my @info = split(/\x00/s,$out);
	foreach (@info){
	    chomp;

	    ## split info string
	    my ($info,$name) = split(/\t/);
	    my ($mode,$type,$blob,$size) = split(/\s+/,$info);
	    my $name = basename( $name );
	    next if ($name=~/^\.gitkeep/);

	    if ( $type eq 'blob' ){
		$content .=
		    qq(
        <entry kind="file">
            <name>$name</name>
            <size>$size</size>
            <commit revision="$revision">
                <author>$owner</author>
                <date>unknown</date>
            </commit>
        </entry>
    );
	    }
	    else{
		$content .=
		    qq(
        <entry kind="dir">
            <name>$name</name>
            <commit revision="$revision">
                <author>$owner</author>
                <date>unknown</date>
            </commit>
        </entry>
     );
	    }
	}
    }
    $content .= "</list>\n";
    return $content;
}


=head2 C<export>

 $storage->export (
     repos   => $repos,
     rev     => $rev,
     src     => $src,
     trg     => $trg,
     archive => $archive)
 )

Exports data from a repository to a target.
If C<$archive> is true, a zip archive with the exported contents will also be created).

Returns: true (an exception is raised on failure).

=cut

sub export {
    my $self  = shift;
    my %params = @_;
    map { $params{$_} = "" unless ( defined( $params{$_} ) ) }
        qw/ repos src trg archive /;

    # default revision = HEAD (last revision)
    $params{rev} = 'HEAD' unless ($params{rev});

    my @paths = split(/\//,$params{src});
    my $user = shift(@paths);
    my $path = join( '/', @paths );

    my $repohome = join( '/', $self->{partition}, $params{repos}, $user );
    if ( $path && $self->_is_file( $repohome, $params{rev}, $path ) ){
	${ $params{trg} } = 
	    $self->_export_file($repohome, 
				$path,
				$params{rev}, 
				$params{archive} );
	get_logger(__PACKAGE__)->debug("git: download file $params{src} to ${ $params{trg} }");
	return 1;
    }
    elsif ( $params{archive} ){
	${ $params{trg} } = 
	    $self->_export_subtree($repohome, $path, $params{rev});
	get_logger(__PACKAGE__)->debug("git: download dir $params{src} to ${ $params{trg} }");
	return 1;
    }
    else{
	raise( 8, 'archive=no option only permitted for single files', 'warn' );
    }
    return 0;
}


sub _export_subtree {
    my $self  = shift;
    my ($repohome, $path, $revision ) = @_;

    # Create temp file to store archive in
    my ( $fh, $target ) = tempfile(
	'zip_download_XXXXXXXX',
	DIR    => $ENV{UPLOADDIR},
	SUFFIX => '.zip',
	UNLINK => 1
	);
    close($fh) or raise( 8, "Could not close file handle: $fh", 'error' );

    my $pwd = getcwd();
    chdir( $repohome );
    # git archive --format=zip --prefix=... -o output.zip rev:path 
    my $prefix = basename($path);
    $path = ':'.$path if ($path);
    get_logger(__PACKAGE__)->info("git archive --format=zip --prefix=$prefix -o $target $revision$path");
    my $success = &run_cmd( 'git',
			    'archive',
			    '--format=zip',
			    '--prefix='.$prefix.'/',
			    '-o', $target,
			    $revision.$path );
    chdir($pwd);
    return $target;
}


sub _export_file {
    my $self  = shift;
    my ($repohome, $path, $revision, $archive) = @_;

    # Create temp dir for svn export
    my $tmp_dir = tempdir(
	'git_export_XXXXXXXX',
	DIR     => $ENV{UPLOADDIR},
	CLEANUP => 1
	);

    my $pwd = getcwd();
    chdir( $repohome );
    if ( $revision eq 'HEAD' ){
	get_logger(__PACKAGE__)->info("git checkout export $path to $tmp_dir");
	my $success = &run_cmd( 'git',
				'checkout-index',
				'--prefix='.$tmp_dir.'/',
				$path );
	## we don't want sub-dir's
	my @parts = split(/\//,$path);
	my $basename = pop(@parts);
	move( $tmp_dir.'/'.$path, $tmp_dir.'/'.$basename ) || raise( 8, $! );
	while (@parts){
	    rmdir( join('/',$tmp_dir,@parts) );
	    pop(@parts);
	}
    }
    else{
	## TODO: implement checking out old revisions of single files
	raise( 8, 'checking out old revisions of files is not implemented in Storage::Git', 'warn' );
    }
    chdir($pwd);

    if ( $archive ){

	my $zip = Archive::Zip->new();

	# Add temp dir to zip archive
	unless ( $zip->addTree($tmp_dir) == AZ_OK ) {
	    rmtree($tmp_dir);
	    raise( 8, 'Wrote nothing to zip archive', 'warn' );
	}

	# Create temp file to store archive in
	my ( $fh, $target ) = tempfile(
	    'zip_download_XXXXXXXX',
	    DIR    => $ENV{UPLOADDIR},
	    SUFFIX => '.zip',
	    UNLINK => 1
	    );
	close($fh) or raise( 8, "Could not close file handle: $fh", 'error' );

	unless ( $zip->writeToFileNamed($target) == AZ_OK ) {
	    rmtree($tmp_dir);
	    raise( 8, 'zip write error', 'error' );
	}

	return $target;
    }
    return join( '/', $tmp_dir, basename( $path ) );
}







sub _is_file{
    my $self = shift;
    my ($reposdir, $rev, $path) = @_;

    my $pwd = getcwd();
    chdir( $reposdir );

    my ($success,$ret,$out,$err) = &run_cmd( 'git',
					     'ls-tree',
					     '-l',
					     $rev,
					     $path );
    chdir($pwd);
    if ($success){
	chomp $out;
	my ($info,$name) = split(/\t/,$out);
	my ($mode,$type,$blob,$size) = split(/\s+/,$info);

	get_logger(__PACKAGE__)->debug("cd $reposdir; git ls-tree -l $rev $path");
	get_logger(__PACKAGE__)->debug("git: _is_file: $name = $type ($path)");

	return 1 unless ($type eq 'tree');
    }
    return 0;
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
