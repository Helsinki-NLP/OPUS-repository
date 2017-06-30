package LetsMT::Repository::Storage::SVNLocal;

=head1 NAME

LetsMT::Repository::VCSubversion - storage backend wrapping a local Subversion

=cut

use strict;
use parent 'LetsMT::Repository::Storage';

use open qw(:std :utf8);

use LetsMT::Repository::StorageManager::Partition;
use LetsMT::Tools;

use LetsMT::Repository::Err;
use Log::Log4perl qw(get_logger :levels);
use Data::Dumper;

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use File::Basename qw/ basename dirname /;
use File::Copy;
use File::Copy::Recursive qw/ rcopy /;
use File::Temp qw(tempfile tempdir);
use File::Find;
use File::Path;
use XML::LibXML;
use IPC::Run qw(run timeout);
use File::Slurp;
use Cwd;

our $SVN      = 'svn';
our $SVNADMIN = 'svnadmin';

# for run_cmd: separate svn-command and it's arguments (here: none)

our $SVN_CMD  = 'svn';
our @SVN_PARA = ('--non-interactive');


=head1 CONSTRUCTOR

 $storage = new LetsMT::Repository::Storage::SVNLocal (%params);

=cut

sub new {
    my $class = shift;
    my %self  = @_;

    $self{SVN}      = $self{SVN}      || $SVN;
    $self{SVNADMIN} = $self{SVNADMIN} || $SVNADMIN;
    $self{SVN_CMD}  = $self{SVN_CMD}  || $SVN_CMD;
    $self{SVN_PARA} = $self{SVN_PARA} || \@SVN_PARA;

    $self{protocol}  = 'file://';
    $self{partition} = $ENV{LETSMTDISKROOT} || '/var/lib';
    $self{base_url}  = join( '/', ( $self{protocol}, $self{partition} ) );

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
    my ( $self, $slot ) = @_;

    # diskpath = partition/slot
    my $path = join( '/', ( $self->{partition}, $slot ) );

    # path exists --> return 2 (is that OK?)
    return 2 if (-d $path);

    get_logger(__PACKAGE__)->info("initialize $path");
    unless ( -d dirname($path) ) {
        mkdir( dirname($path), 0700 ) or raise( 8, "mkdir $path" );
    }

    # try to create the repository
    my ( $success, $ret, $out, $err ) = run_cmd(
        $self->{SVNADMIN},
        'create',
        $path
    );
    return 1 if ($success);

    # throw an error otherwise
    my @err_lines = <$err>;
    raise( 8, "cannot create svn-repo $path: " . Dumper(@err_lines) );
}



=head2 C<mkdir>

 $storage->mkdir ($repos, $branch, $user, $dir)

A wrapper around C<svn mkdir>.

Returns: true if directory already exists, or creation went well.
An exception is raised on creation failure.

=cut

sub mkdir {
    my ( $self, $repos, $branch, $user, $dir ) = @_;
    my $workdir = undef;

    # return 1 if the path exists already
    return 1 if ( $self->is_path(
            repos  => $repos,
            branch => $branch,
            dir    => $dir,
        )
    );

    get_logger(__PACKAGE__)->info("mkdir $repos/$branch/$dir");

    my $path = join( '/',
        $self->{base_url},
        $repos,
        $branch,
        $dir
    );

    my ( $success, $ret, $out, $err ) = run_cmd(
        $self->{SVN_CMD},
        @{$self->{SVN_PARA}},
        'mkdir',
        '-m','mkdir',
        '--parents',
        '--quiet',
        $path
    );

    return 1 if ($success);

    # check once again whether the path exists 
    # (maybe another process created it in the mean time?)
    return 1 if ( $self->is_path(
            repos => $repos,
            branch => $branch,
            dir => $dir,
        )
    );

    # throw an error otherwise
    my @err_lines = <$err>;
    raise( 8, "mkdir $repos/$branch/$dir: " . Dumper(@err_lines) );
}


=head2 C<copy>

 $storage->copy ($user, $slot, $source, $target)

A wrapper around C<svn copy>.

Returns: true (an exception is raised on failure).

=cut

## TODO: do we need to check the user?

sub copy {
    my ( $self, $user, $slot, $src, $trg ) = @_;

    my $srcpath = join('/',$self->{base_url}, $slot, $src );
    my $trgpath = join('/',$self->{base_url}, $slot, $trg );

    my ( $success, $ret, $out, $err ) = run_cmd(
        $self->{SVN_CMD},
        @{$self->{SVN_PARA}},
        '--quiet',
        'copy',
        '-m',
        "copy branch $src to $trg",
        $srcpath,
        $trgpath
    );

    return 1 if ($success);

    # throw an error otherwise
    my @err_lines = <$err>;
    raise( 8, "copy $srcpath to $trgpath: " . Dumper(@err_lines) );
}


=head2 C<is_path>

 $result = $storage->is_path (
     repos  => $repos,
     branch => $branch,
     dir    => $dir,
     file   => $file,
     rev    => $revision,
 )

Check whether the specified file or dir exists. 

Returns: true or false.

=cut

sub is_path {
    my $self  = shift;
    my %params = @_;
    map { $params{$_} = "" unless ( defined( $params{$_} ) ) }
        qw/ repos branch dir file /;

    my $path = join( '/',
        $self->{base_url},
        $params{repos},
        $params{branch},
        $params{dir},
        $params{file}
    );

    my ($success, $ret, $out, $err) = run_cmd(
        $self->{SVN_CMD},
        @{$self->{SVN_PARA}},
        'list',
        "$path\@$params{rev}"
    );

    return $success;
}



=head2 C<list>

 $storage->list ( repos => $repos, dir => $dir )

A wrapper around <svn list>.
We use XML that subversion produces.

Returns: a string with an XML-document of a file listing.

=cut

sub list {
    my $self  = shift;
    my %params = @_;

    # Create path and get XML listing from SVN
    my $path = join( '/',
        $self->{base_url},
        $params{repos},
        $params{dir},
    );

    my ($success, $ret, $out, $err) = run_cmd(
        $self->{SVN_CMD},
        @{$self->{SVN_PARA}},
        'list',
        '--xml',
        '--incremental',
        $path.'@'.$params{rev}
    );

    ## success! --> return clean listing
    if ($success && $ret == 0){
        return $self->_cleanup_listing( $out , $params{slot} );
    }

    ## otherwise --> error
    my $xmlpath = LetsMT::Tools::xmlify($path);
    return "<list path=\"/$xmlpath\"></list>\n";
}





sub status {
    my $self  = shift;
    my %params = @_;

    my ($success, $ret, $out, $err) = run_cmd(
        $self->{SVN_CMD},
        @{$self->{SVN_PARA}},
        'status',
        '--xml',
        '--incremental'
    );

    ## success! --> return clean listing
    if ($success && $ret == 0){
        return $self->_cleanup_listing( $out , $params{slot} );
    }

    ## otherwise --> error
    return "<list path=\"\"></list>\n";
}




=head2 C<revisions>

 %revisions = $storage->revisions (@path_elements)

Returns: a list of revisions for a given resource

=cut

sub revisions{
    my $self = shift;
    my $path = join( '/', $self->{base_url}, @_ );

    my ($success, $ret, $out, $err) = run_cmd(
        $self->{SVN_CMD},
        @{$self->{SVN_PARA}},
        'log',
        "$path@");

    my @loginfo = split(/\n/s,$out);

    my %revisions = ();
    foreach (@loginfo){
        if (/^r([0-9]+)\s/){
            my $rev = $1;
            my ($r,$u,$date) = split(/\s+\|\s+/);
            $revisions{$rev} = $date;
        }
    }
    return %revisions;
}


=head2 C<cat>

 $content = $storage->cat ($range, $path, $uid, $rev)

A wrapper around C<svn cat>.

Returns: the content of the given file.

=cut


## TODO: do we need to check uid? (or remove uid argument?)
## TODO: should we have an upper limit to avoid full memory?

sub cat {
    my $self = shift;
    my ($range, $path, $uid, $rev) = @_;

    # Create path and get XML listing from SVN
    my $resource = join( '/',
        $self->{base_url},
        @{$path}
    );

    my ( $cmd, $in, $out, $err ) = open_cmd(
        $self->{SVN_CMD},
        @{$self->{SVN_PARA}},
        'cat',
        "$resource\@$rev",
    );
    if ($cmd) {
        #    binmode($out);
        binmode( $out, ":encoding(utf8)" );
        my $content = undef;
        my $count = 0;
        my ($from,$to) = (0,undef);
        if (ref($range) eq 'HASH'){
            $from = $$range{from} if (defined $$range{from});
            $to = $$range{to} if (defined $$range{to});
        }
        while (<$out>) {
            if ($count >= $from){
                $content .= $_;
            }
            $count++;
            last if (defined $to && $count>$to);
        }
        close $out;
        close_cmd($cmd);

        # no content? --> check for errors!
        unless (defined $content){
            my @err_lines = <$err>;
            if (@err_lines){
                get_logger(__PACKAGE__)
                    ->error("error reading $resource" . Dumper(@err_lines) );
            }
        }

        # success? --> return content
        return $content;
    }

    raise( 8, 'Could not find resource: ' . $resource );
}


=head2 C<add>

 $storage->add ($user, $repos, $branch, $path, $file, $source)

Add a file (source) to a repository as C<$path>/C<$file>.
It is done by checking out the holding directory
completely empty (in order to minimize traffic volumes),
and then proceeding with add and commit.

Returns: true (an exception is raised on failure).

=cut


sub add {
    my ( $self, $user, $repos, $branch, $path, $file, $source ) = @_;

    get_logger(__PACKAGE__)->info("add $repos/$branch/$path/$file");

    my $workdir = tempdir(
        'svn_add_XXXXXXXX',
        DIR     => $ENV{UPLOADDIR},
        CLEANUP => 1
        );

    $self->checkout(
        repos => $repos,
        rev   => "HEAD",
        src   => join( '/', ( $branch, $path ) ),
        trg   => $workdir,
        flags => '--depth empty'
    );

    my $pwd = getcwd();
    chdir($workdir);

    # move everything to the workdir
    move( $source, join( '/', $workdir, $file ) ) || raise( 8, $! );

    my ($success,$ret,$out,$err) = $self->add_file( $user, $file );

    unless ($success) {
        chdir($pwd);
        rmtree($workdir);
        my @err_lines = <$err>;
        raise( 8, "cannot add files: " . Dumper(@err_lines) );
    }

    my ( $success, $ret, $out, $err ) = 
	$self->commit( $user, "$workdir/$file", 'add');

    unless ($success){
        chdir($pwd);
        rmtree($workdir);
        my @err_lines = <$err>;
        raise( 8, "cannot commit files: " . Dumper(@err_lines) );
    }

    chdir($pwd);
    rmtree($workdir);
    return 1;
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

    my @path_elements = split( /\/+/, $path );

    # try to add a new resource
    # - go to parent directories if adding is not successful
    #   (usually because the current path is not a working copy yet)
    # - this will recursively add resources in those directories
    #   (TODO: is that a problem?)
    # - we also use --force to add all unversioned files in all sub-dir's
    #   (TODO: is that a problem?)
    my ($success,$ret,$out,$err);
    while (@path_elements){
	($success,$ret,$out,$err) = &run_cmd( $self->{SVN_CMD},
					      @{$self->{SVN_PARA}},
					      '--quiet',
					      '--username', $user,
					      '--force',
					      'add',
					      join('/',@path_elements) );
	last if ($success);
	pop(@path_elements);
    }
    return ($success,$ret,$out,$err);
}


=head2 C<commit>

 $storage->commit ($user, $path, $message )

Commit all changes in the given path with message $message.

Returns: ( $success, $return_code, $stdout, $stderr )

 $success = true if successful
 $return_code = return code of the system call
 $stdout = reference to stdout of the system call
 $stderr = reference to stderr of the system call

=cut


sub commit{
    my ( $self, $user, $dir, $message) = @_;
    my ($success,$ret,$out,$err) = &run_cmd( $self->{SVN_CMD},
					   @{$self->{SVN_PARA}},
					   '--quiet',
					   '--username',$user,
					   'commit',
					   '-m', $message,
					   $dir );
    return ($success,$ret,$out,$err);
}







=head2 C<update>

 $storage->update ($self, $user, $repos, $branch, $path, $file, $source)

Update a repository with the given file (source).

Returns: true (an exception is raised on failure)

=cut

sub update {
    my ( $self, $user, $repos, $branch, $path, $file, $source ) = @_;

    get_logger(__PACKAGE__)->info("update $repos/$branch/$path/$file");

    my $workdir = tempdir(
        'svn_update_XXXXXXXX',
        DIR     => $ENV{UPLOADDIR},
        CLEANUP => 1
        );

    $self->checkout(
        repos => $repos,
        rev   => "HEAD",
        src   => join( '/', ( $branch, $path ) ),
        trg   => $workdir,
        flags => '--depth empty'
    );

    my $pwd = getcwd();
    chdir($workdir);

    # update from old revisions
    my ($success,$ret,$out,$err) = run_cmd(
        $self->{SVN_CMD},
        @{$self->{SVN_PARA}},
        '--quiet',
        '--username', $user,
        'update',
        $file);

    unless ($success) {
        chdir($pwd);
        rmtree($workdir);
        my @err_lines = <$err>;
        raise( 8, "cannot update '$file': " . Dumper(@err_lines) );
    }

    # move the new file into the workdir
    move( $source, join( '/', $workdir, $file ) ) or raise( 8, $! );

    # and finally commit the new file
    my ( $success, $ret, $out, $err ) = run_cmd(
        $self->{SVN_CMD},
        @{$self->{SVN_PARA}},
        '--quiet',
        '--username', $user,
         'commit',
        '-m', 'update',
        "$workdir/$file");

    unless ($success) {
        chdir($pwd);
        rmtree($workdir);
        my @err_lines = <$err>;
        raise( 8, "cannot update '$file': " . Dumper(@err_lines) );
    }

    chdir($pwd);
    rmtree($workdir);
    return 1;
}


=head2 C<remove>

 $storage->remove (
     repos => $repos,
     dir   => $dir,
     user  => $user,
 )

Remove objects from the repository.

Returns: true (an exception is raised on failure)

=cut

sub remove {
    my $self  = shift;
    my %params = @_;
    map { $params{$_} = "" unless ( defined( $params{$_} ) ) }
        qw/ repos dir user /;

    if ( $params{dir} ) {
        my $path = join( '/', $params{repos}, $params{dir} );
        get_logger(__PACKAGE__)->info("remove $path");

        my ($success,$ret,$out,$err) = run_cmd(
            $self->{SVN_CMD},
            @{$self->{SVN_PARA}},
            '--quiet',
            '--username', $params{user},
            'rm',
            '-m', 'delete',
            "$self->{base_url}/$path" );

        unless ($success) {
            my @err_lines = <$err>;
            raise( 8, "cannot delete '$path': " . Dumper(@err_lines) );
        }
    }
    else {
        get_logger(__PACKAGE__)->info("remove repository $params{repos}");

        # TODO: do something useful when deleting slots
        # (make it possible to recover, store information about deleted resources ...)

#      my ($fh, $filename) = tempfile(basename($params{repos}).".DELETED.XXXXXXXX", DIR => dirname($params{repos}));
#      close($fh);
#      unlink($filename); #FIXME: race condition starts

        # simplistic solution: only allow one copy of a deleted resource
        # TODO: racing conditions, multiple versions? customizable

        my $filename = $params{repos} . '.DELETED';

        my $srcpath = $self->{partition} . '/' . $params{repos};
        my $trgpath = $self->{partition} . '/' . $params{repos} . '.DELETED';

        #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        # If old 'deleted' directory exists, remove it
        # TODO: this is very! dangerous!!!! check if this can go wrong ...!!!
        #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        if ( -d $trgpath ) {
            if ( $trgpath ne $self->{partition} ) {
                rmtree($trgpath)
                    or raise( 8, "cannot remove $trgpath (" . $! . ')' );
            }
        }

        #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        # Rename to-be-deleted directory by attaching '.DELETED'
        move( $srcpath, $trgpath )
            or raise( 8, "cannot move '$srcpath' to '$trgpath'" );
    }
    return 1;
}


=head2 C<checkout>

 $storage->checkout (
     repos => $repos,
     rev   => $rev,
     src   => $src,
     trg   => $trg,
     flags => $flags
 )

Check out data from the repository.

Returns: true (an exception is raised on failure)

=cut

sub checkout {
    my $self  = shift;
    my %params = @_;
    map { $params{$_} = "" unless ( defined( $params{$_} ) ) }
        qw/ repos rev src trg flags /;

    my $path  = join( '/',
        $self->{base_url},
        $params{repos},
        $params{src}
    );
    my @flags = split(/\s+/, $params{flags});

    my ( $success, $ret, $out, $err ) = run_cmd(
        $self->{SVN_CMD},
        @{$self->{SVN_PARA}},
        'info',
        "$path\@$params{rev}",
        @flags
    );

    my $type = $out;
    $type =~ s/^.*Node kind: (\S+).*?$/$1/si;
    chomp($type);

    ### Check out to target
    my ( $success, $ret, $out, $err ) = run_cmd(
        $self->{SVN_CMD},
        @{$self->{SVN_PARA}},
        '--quiet',
        'checkout',
        "$path\@$params{rev}",
        $params{trg},
        @flags
    );

    return 1 if ($success);

    # throw an error otherwise
    my @err_lines = <$err>;
    raise( 8, "checkout $path: " . Dumper(@err_lines) );
}


=head2 C<info>

 $storage->info (
     repos => $repos,
     dir   => $dir,
     rev   => $rev
 )

Get information about a path in the repository

Returns: a key-value hash with info

=cut

sub info{
    my $self  = shift;
    my %params = @_;

    my $path  = join( '/', $self->{base_url}, $params{repos}, $params{dir} );

    my ( $success, $ret, $out, $err ) = run_cmd(
	$self->{SVN_CMD},
        @{$self->{SVN_PARA}},
        'info',
        "$path\@$params{rev}"
    );

    my %info=();
    my @lines = split(/\n/,$out);
    foreach (@lines){
	chomp;
	my ($key, $value) = split(/\:\s+/);
	$info{$key} = $value;
    }
    return %info;
}


=head2 C<export>

 $storage->export (
     repos   => $repos,
     rev     => $rev,
     src     => $src,
     trg     => $trg,
     flags   => $flags
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
        qw/ repos src trg flags archive /;

    # default revision = HEAD (last revision)
    $params{rev} = 'HEAD' unless ($params{rev});

    my $basename = basename( $params{src} );
    my $path  = join( '/',
        $self->{base_url},
        $params{repos},
        $params{src}
    );
    my @flags = split(/\s+/,$params{flags});

    # Create temp dir for svn export
    my $tmp_dir = tempdir(
        'svn_export_XXXXXXXX',
        DIR     => $ENV{UPLOADDIR},
        CLEANUP => 1
    );

    my ( $success, $ret, $out, $err ) = run_cmd(
        $self->{SVN_CMD},
        @{$self->{SVN_PARA}},
        '--quiet',
        'export',
        "$path\@$params{rev}",
        "$tmp_dir/$basename",
        @flags
    );

    unless ($success){
        rmtree($tmp_dir);
        raise( 8, 'Could not export SVN files/dir: '.$path, 'error' );
    }

    # If zip-archive was requested (default), 
    # create zip and store path in in-argument $params{target}
    if ( $params{archive} ) {
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

        ${ $params{trg} } = $target;
    }
    else {
        # If archive=no option...
        # Check if only one file was exported
        unless ( -f $tmp_dir.'/'.$basename ) {
            raise( 8, 'archive=no option only permitted for single files',
                   'warn' );
        }
        ${ $params{trg} } = $tmp_dir.'/'.$basename;
    }

    return 1;
}



=head1 INTERNAL METHOD

=head2 C<_cleanup_listing>

 $listing = $storage->_cleanup_listing ($listing, $slotobject)

A simplistic way to cleanup absolute paths from the svn listings.

=cut

sub _cleanup_listing {
    my $self = shift;
    my ( $contents, $slotobj ) = @_;

    # Remove partition part from the path and save it in temp var
    my $qp = quotemeta( $slotobj->partition );
    $contents =~ s/file\:\/\/$qp//s;
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
