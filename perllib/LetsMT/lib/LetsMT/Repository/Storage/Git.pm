package LetsMT::Repository::Storage::Git;

#
# TODO's
# 
# * should we create empty .gitkeep files to keep 
#   empty dir's in the repository? 
#   --> this would also make "git rm -r" work correctly 
#
# * do we need repository locks when adding files?
#  
#


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


=head1 METHODS

=head2 C<init>

 $storage->init ($path)

Initialize a new subversion repository.

Returns: true (an exception is raised on failure).

=cut

sub init {
    my ( $self, $slot ) = @_;

    # diskpath = partition/slot
    my $path = join( '/', ( $self->{partition}, $slot ) );

    get_logger(__PACKAGE__)->info("initialize $path");

    # try to create the repository
    my ( $success, $ret, $out, $err ) = run_cmd(
        'git',
        'init',
        $path
    );
    return 1 if ($success);

    # throw an error otherwise
    my @err_lines = <$err>;
    raise( 8, "cannot create git-repo $path: " . Dumper(@err_lines) );

    # initialize the compressed files system backend (parent class)
    return $self->SUPER::init(@_);
}


sub _add_files{
    my ($self, $user, $repos, $dir) = @_;

    get_logger(__PACKAGE__)->debug("git: add_files $user $repos $dir");

    my $repohome = join( '/', $self->{partition}, $repos );

    my $pwd = getcwd();
    chdir($repohome);
    get_logger(__PACKAGE__)->debug("git add $dir in $repohome");
    my ($success,$ret,$out,$err) = &run_cmd( 'git', 'add', $dir );
    chdir($pwd);

    unless ($success) {
	my @err_lines = <$err>;
	raise( 8, "cannot add files: " . Dumper(@err_lines) );
    }

    my ( $success, $ret, $out, $err ) = 
	$self->commit( $user, $repos, $dir, 'add '.$dir);

#    unless ($success) {
#	my @err_lines = <$err>;
#	raise( 8, "cannot commit files: " . Dumper(@err_lines) );
#    }
    return 1;
}


=head2 C<mkdir>

=cut

sub mkdir {
    my $self = shift;
    my ( $repos, $branch, $user, $dir ) = @_;

    get_logger(__PACKAGE__)->debug("git: mkdir $repos $branch $user $dir");
    if ( $self->SUPER::mkdir(@_) ){

	my $repohome = join( '/', $self->{partition}, $repos );
	my $file = join( '/', $branch, $dir, '.gitkeep' );
	touch( join( '/', $repohome, $file ) );
	$self->_add_files($user, $repos, $file);
	return 1;
    }
}

=head2 C<copy>

 $storage->copy ($user, $slot, $source, $target)

copy an entire sub-tree

Returns: true (an exception is raised on failure).

=cut

sub copy {
    my $self = shift;
    my ( $user, $slot, $src, $trg ) = @_;

    if ( $self->SUPER::copy(@_) ){
	return $self->_add_files( $user, $slot, $trg )
    }
    return 0;
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
        my $homedir  = join( '/', $self->{partition}, $repos );
        my $fullpath = join( '/', $self->{partition}, $repos, $branch, $dir, $file );
        my $relpath  = join( '/', $branch, $dir, $file );

	my $pwd = getcwd();
	chdir($homedir);
	get_logger(__PACKAGE__)->info("git: add $relpath in $homedir");
	my ($success,$ret,$out,$err) = &run_cmd( 'git',
						 'add',
						 $relpath );
	chdir($pwd);

	unless ($success) {
	    unlink($fullpath);
	    my @err_lines = <$err>;
	    raise( 8, "cannot add files: " . Dumper(@err_lines) );
	}

	my ( $success, $ret, $out, $err ) = 
	    $self->commit( $user, $repos, $relpath, 'add '.$relpath);

	unless ($success) {
#	    unlink($fullpath);
	    my @err_lines = <$err>;
	    raise( 8, "cannot commit files: " . Dumper(@err_lines) );
	}
	return 1;
    }
    return 0;
}




=head2 C<add_file>

 $storage->add_file ($user, $file )

Register a file (source) to be added to a repository as C<$path>/C<$file>.

Returns: ( $success, $return_code, $stdout, $stderr )

 $success = true if successful
 $return_code = return code of the system call
 $stdout = reference to stdout of the system call
 $stderr = reference to stderr of the system call

=cut


sub add_file {
    my ( $self, $user, $path ) = @_;
    my ($success,$ret,$out,$err) = &run_cmd( 'git',
					     'add',
					     $path );
    return ($success,$ret,$out,$err);
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

    my $repohome = join( '/', $self->{partition}, $params{repos} );

    get_logger(__PACKAGE__)->info("git: rm -r $params{dir} in ".$repohome);

    ## delete all files in subtree
    if ($params{dir}){

	my $pwd = getcwd();
	chdir( $repohome );
	my ($success,$ret,$out,$err) = &run_cmd( 'git',
						 'rm',
						 '-r',
						 $params{dir} );
	chdir($pwd);

	unless ($success) {
	    my @err_lines = <$err>;
	    raise( 8, "cannot remove: " . Dumper(@err_lines) );
	}

	my ( $success, $ret, $out, $err ) = 
	    $self->commit( $params{user}, $params{repos}, $params{dir}, 'remove '.$params{dir});

	unless ($success) {
	    my @err_lines = <$err>;
	    raise( 8, "cannot commit files: " . Dumper(@err_lines) );
	}
	return 1;
    }


    ## remove entire repository
    ## make a backup in 
    else{

	## THIS LOOKS QUITE DANGEROUS
	## TODO: MAKE SURE THAT NOTHING CAN GO WRONG HERE
	my $backup = join( '/', $self->{partition},'.DELETED.', $params{repos} );

	get_logger(__PACKAGE__)->debug("git: remove slot (backup at $backup)");

	if ( -d $backup ) {
	    if ($params{repos} && $params{repos}!~/^\./ && 
		$params{repos}!~/\.\.\// && $params{repos}!~/\s/){
		if ($params{partition} && $params{partition}!~/^\./ 
		    && $params{partition}!~/\.\.\//){
		    rmtree($backup)
			or raise( 8, "cannot remove $backup (" . $! . ')' );
		}
	    }
	}
	get_logger(__PACKAGE__)->debug("git: move $repohome to $backup)");
	raise( 8, "cannot copy over to $backup") if ( -d $backup );

	unless ( -d dirname($backup) ) {
            mkdir( dirname($backup) )  or raise( 8, "mkdir ".dirname($backup) );
        }
	move( $repohome, $backup ) || raise( 8, $! );
	return 1;
    }




    # my $path = join( '/', $self->{partition}, $params{repos}, $params{dir} );

    # if ($self->SUPER::remove(%params)){
    # 	$self->commit( $params{user}, $path, 'remove '.$params{dir});
    # 	return 1 unless (-e $path);
    # }
    # return 0;


    # ## use parent if we want to remove the entire repo
    # unless ($params{dir}){
    # 	return $self->SUPER::remove(@_);
    # }

    # my $path = join( '/',
    #     $self->{partition}, $params{repos}, $params{dir}
    # );

    # my $pwd = getcwd();
    # chdir( dirname($path) );
    # get_logger(__PACKAGE__)->info("git: rm -r $params{dir} in ".dirname($path));
    # my ($success,$ret,$out,$err) = &run_cmd( 'git',
    # 					     'rm',
    # 					     '-r',
    # 					     $params{dir} );
    # chdir($pwd);

    # unless ($success) {
    # 	my @err_lines = <$err>;
    # 	raise( 8, "cannot remove: " . Dumper(@err_lines) );
    # }

    # my ( $success, $ret, $out, $err ) = 
    # 	$self->commit( $params{user}, $path, 'remove '.$params{dir});

    # unless ($success) {
    # 	my @err_lines = <$err>;
    # 	raise( 8, "cannot commit files: " . Dumper(@err_lines) );
    # }
    # return $self->SUPER::remove(%params);
    # return 1;
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

    $message = 'unknown reason' unless ($message);
    my $repohome = join( '/', $self->{partition}, $repos );

    my $pwd = getcwd();
    chdir( $repohome );
    get_logger(__PACKAGE__)->info("cd $repohome; git commit -am $message ($dir)");
    my ($success,$ret,$out,$err) = &run_cmd( 'git',
					     'commit',
					     '-am', 
					     $message );
    chdir($pwd);

    return ($success,$ret,$out,$err);
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
	chomp $out;
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

    my $repohome = join( '/', $self->{partition}, $params{repos} );
    my $path_to_display = join( '/', $params{repos}, $params{dir} );
    my $revision = $params{revision} || 'HEAD';

    my $path = $params{dir};
    unless ( $self->_is_file( $repohome, $revision, $path )){
	$path .= '/';
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
    my $repohome = join( '/', $self->{partition}, $params{repos} );

    if ( $self->_is_file( $repohome, $params{rev}, $params{src} ) ){
	${ $params{trg} } = 
	    $self->_export_file($repohome, 
				$params{src},
				$params{rev}, 
				$params{archive} );
	get_logger(__PACKAGE__)->debug("git: download file $params{src} to ${ $params{trg} }");
	return 1;
    }
    elsif ( $params{archive} ){
	${ $params{trg} } = 
	    $self->_export_subtree($repohome, $params{src}, $params{rev});
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
    get_logger(__PACKAGE__)->info("git: export $revision:$path to $target");
    my ($success,$ret,$out,$err) = &run_cmd( 'git',
					     'archive',
					     '--format=zip',
					     '-o', $target,
					     $revision.':'.$path );
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
	# git checkout-index --prefix=$tmp_dir/  publications/NAACL2018/nmt-standard.pdf
	get_logger(__PACKAGE__)->info("git: export $path to $tmp_dir");
	my ($success,$ret,$out,$err) = &run_cmd( 'git',
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
