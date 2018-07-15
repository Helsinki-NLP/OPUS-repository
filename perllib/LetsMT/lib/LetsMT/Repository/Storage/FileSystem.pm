package LetsMT::Repository::Storage::FileSystem;

=head1 NAME

LetsMT::Repository::Storage::FileSystem - storage backend using simple files on disk

=cut

use strict;
use parent 'LetsMT::Repository::Storage';
use open qw(:std :utf8);

use LetsMT::Tools;
use Archive::Zip qw(:ERROR_CODES :CONSTANTS);
use Encode qw(encode decode);
use File::Basename;
use File::Path;
use File::Copy qw(move);
use File::stat;
use File::Temp qw(tempfile tempdir);

use Log::Log4perl qw(get_logger :levels);
use LetsMT::Repository::Err;
use Data::Dumper;


=head1 CONSTRUCTOR

 $storage = new LetsMT::Repository::Storage::FileSystem (%params);

=cut

sub new {
    my $class = shift;
    my %self  = @_;

    $self{partition} = &LetsMT::Repository::StorageManager::Partition::select_part(undef);

    bless \%self, $class;
    return \%self;
}


=head1 METHODS

=head2 C<init>

 $storage->init ($path)

Initialize a new storage path.

=cut

sub init {
    my ( $self, $path ) = @_;
    unless ( -d $path ) {
        get_logger(__PACKAGE__)->info("initialize $path");
        unless ( -d dirname($path) ) {
            mkdir( dirname($path) )  or raise( 8, "mkdir $path" );
        }
    }
    return 1;
}


=head2 C<mkdir>

=cut

sub mkdir {
    my ( $self, $repos, $branch, $user, $dir ) = @_;

    my $path = join( '/',
        $self->{partition}, $repos, $branch, $dir
    );
    my ( $success, $ret, $out, $err) = run_cmd( 'mkdir', '-p', $path );
    return 1 if ($success);

    my @err_lines = <$err>;
    raise( 8, "cannot make path $path: " . Dumper(@err_lines) );
}


=head2 C<is_path>

=cut

sub is_path {
    my $self  = shift;
    my %params = @_;

    map { $params{$_} = "" unless ( defined( $params{$_} ) ) }
        qw/ repos branch dir file /;

    my $path = join( '/',
        $self->{partition},
        $params{repos},
        $params{branch},
        $params{dir}
    );
    return ( -e $path );
}


=head2 C<copy>

=cut

sub copy {
    my ( $self, $user, $slot, $src, $trg ) = @_;

    my $srcpath = join( '/', $self->{partition}, $slot, $src );
    my $trgpath = join( '/', $self->{partition}, $slot, $trg );

    my ( $success, $ret, $out, $err) = run_cmd( 'cp', '-R', $srcpath, $trgpath );
    return 1 if ($success);

    my @err_lines = <$err>;
    raise( 8, "cannot copy $srcpath to $trgpath: " . Dumper(@err_lines) );
}


=head2 C<add>

=cut

sub add {
    my ( $self, $user, $repos, $branch, $dir, $file, $source ) = @_;

    if ( $self->mkdir( $repos, $branch, $user, $dir ) ) {
        my $path = join( '/',
            $self->{partition}, $repos, $branch, $dir, $file
        );
	get_logger(__PACKAGE__)->error("git: $source not found") unless (-e $source);
	get_logger(__PACKAGE__)->info("git: move $source to $path");
        move( $source, $path ) || raise( 8, $! );
        return $path;
    }
    return 0;
}


=head2 C<update>

Functionally identical to C<add>.

=cut

# update is actually the same as 'add' (simply overwrite!)

sub update {
    my $self = shift;
    return $self->add(@_);
}


=head2 C<remove>

=cut

sub remove {
    my $self  = shift;
    my %params = @_;
    map { $params{$_} = "" unless ( defined( $params{$_} ) ) }
        qw/ repos dir user /;

    my $srcpath = join( '/',
        $self->{partition}, $params{repos}, $params{dir}
    );
    my $trgpath = join( '/',
        $self->{partition}, '.DELETED.', $params{repos}, $params{dir}
    );

    #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    # If old 'deleted' directory exists, remove it
    # TODO: this is very! dangerous!!! check if this can go wrong ...!!!
    #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    if ( -d $trgpath ) {
        if ( $trgpath ne $self->{partition} ) {
            rmtree($trgpath)
                or raise( 8, "cannot remove $trgpath (" . $! . ')' );
        }
    }

    #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    # make the target directory
    $self->mkdir(
        '.DELETED.',   $params{repos} . '/' . $params{branch},
        $params{user}, dirname( $params{dir} )
    );

    # Rename to-be-deleted directory by attaching '.DELETED'
    move( $srcpath, $trgpath )
        or raise( 8, "cannot move '$srcpath' to '$trgpath'" );

    return 1;
}


=head2 C<export>

 $storage->export( %params )

Parameters:

 repos
 rev
 src
 trg
 flags
 archive

=cut

sub export {
    my $self  = shift;
    my %params = @_;
    map { $params{$_} = "" unless ( defined( $params{$_} ) ) }
        qw/ repos rev src trg flags archive /;

    my $path = join( '/',
        $self->{partition}, $params{repos}, $params{src}
    );

    # TODO: why do we need to encode as utf8?
    my $dest = encode( 'utf8', basename($path) );

    if ( $params{archive} ) {
        # make a new zip archive and the target without its path
        my $zip = Archive::Zip->new();
        if ( -f $path ) {
            $zip->addFile( $path, $dest );
        }
        elsif ( -d $path ) {
            unless ( $zip->addTree( $path, $dest ) == AZ_OK ) {
                raise( 8, 'Wrote nothing to zip archive', 'warn' );
            }
        }
        else {
            raise( 8, 'Cannot find path "$path"', 'warn' );
        }

        # Create temp file to store archive in
        my ( $fh, $target ) = tempfile(
            'zip_download_XXXXXXXX',
            DIR    => $ENV{UPLOADDIR},
            SUFFIX => '.zip',
            UNLINK => 1
        );
        close($fh)
            or raise( 8, 'Could not close file handle: ' . $fh, 'error' );

        unless ( $zip->writeToFileNamed($target) == AZ_OK ) {
            raise( 8, 'zip write error', 'error' );
        }
        ${ $params{trg} } = $target;
    }
    else {
        # If archive=no option...
        # Check if only one file was exported
        raise(
            8,
            'archive=no option only permitted for single files',
            'warn'
        ) unless ( -f $path );

        # Create temp dir and make a symbolic link to the actual file
        # this is necessary because the system will otherwise
        # delete the original file!!! (if we just give the path to it back)
        my $tmp_dir = tempdir(
            'filesystem_export_XXXXXXXX',
            DIR     => $ENV{UPLOADDIR},
            CLEANUP => 1
        );
        my $safe_path = &LetsMT::Tools::safe_path($path);

        # TODO: this is ugly --> find a better way to do this!
        # system("ln -s $safe_path $tmp_dir/tmpfile.tmp");
        my $success = &run_cmd('ln', '-s', $path, $tmp_dir.'/tmpfile.tmp');

        ${ $params{trg} } = $tmp_dir . '/tmpfile.tmp';
    }
    return 1;
}


=head2 C<list>

 $list = $storage->list( %params )

Parameters:

 repos
 dir
 branch

=cut

sub list {
    my $self  = shift;
    my %params = @_;
    map { $params{$_} = "" unless ( defined( $params{$_} ) ) }
        qw/ repos dir branch /;

    # need owner name to set 'author' attribute
    my $owner = length $params{branch} ? $params{branch}->owner() : 'unknown';

    my $path = join( '/',
        $self->{partition}, $params{repos}, $params{dir}
    );
    my $path_to_display = join( '/',
        $params{repos}, $params{dir}
    );
    my $revision = $params{revision} || $self->revision( $owner, $path );

    my $content = qq(<?xml version="1.0"?><list path="/$path_to_display">);

    if ( -f $path ) {
        $content .= &_list_file( $path, $owner, $revision );
    }
    elsif ( -d $path ) {
        opendir( my $dh, $path )
            or raise( 8, "cannot open dir '$path'", 'warn' );

        ## TODO: readdir is one of the few places where utf8 decoding is really still needed
        ## http://perldoc.perl.org/perlunicode.html#When-Unicode-Does-Not-Happen
        ## TODO: utf8::all seems to be close to enabling utf8 for readdir...
        while ( my $f = decode( 'utf8', readdir $dh ) ) {
            next if ( $f =~ /^\.+$/ );
            next if ( $f =~ /^\.svn$/ );
            next if ( $f =~ /^\.git$/ );
            if ( -f "$path/$f" ) {
                $content .= &_list_file( "$path/$f", $owner, $revision );
            }
            elsif ( -d "$path/$f" ) {
                $content .= &_list_dir( "$path/$f", $owner, $revision );
            }
        }
        closedir $dh;
    }
    $content .= "</list>\n";
    return $content;
}


=head2 C<_list_file>

 $entry = &_list_file( $path, $owner )

=cut

sub _list_file
{
    my $file  = shift or return "";
    my $owner = shift or die "invalid input";
    my $revision = shift;

    return "" unless -f $file;

    my $f = basename( $file );
    my $size = -s $file;
    my $mtime = localtime( stat($file)->mtime );
    return qq(
        <entry kind="file">
            <name>$f</name>
            <size>$size</size>
            <commit revision="$revision">
                <author>$owner</author>
                <date>$mtime</date>
            </commit>
        </entry>
    );
}


=head2 C<_list_dir>

 $entry = &_list_dir( $path, $owner, $revision )

=cut

sub _list_dir
{
    my $dir   = shift or return "";
    my $owner = shift or die "invalid input";
    my $revision = shift;

    return "" unless -d $dir;

    my $f = basename( $dir );
    my $mtime = localtime( stat($dir)->mtime );
    return qq(
        <entry kind="dir">
            <name>$f</name>
            <commit revision="$revision">
                <author>$owner</author>
                <date>$mtime</date>
            </commit>
        </entry>
    );
}


=head2 C<cat>

 $content = $storage->cat( $range, $dir )

=cut

sub cat {
    my ( $self, $range, $dir ) = @_;

    # need a path reference
    return '' if ( ref($dir) ne 'ARRAY' );

    my $path = join( '/',
        $self->{partition}, @{$dir}
    );

    raise( 8, "archive=no option only permitted for single files", 'warn' )
        unless ( -f $path );

    my $safe_path = &safe_path( $self->{partition}, @{$dir} );

    if ( ref($range) eq 'HASH' ) {
        if ( $range->{'from'} ) {
            if ( $range->{'to'} ) {
                my $size = $range->{to} - $range->{from};
                return `head -$range->{to} < $safe_path | tail -$size`;
            }
            return `tail -n  +$range->{from} < $safe_path`;
        }
        if ( $range->{'to'} ) {
            return `head -$range->{to} < $safe_path`;
        }
    }
    ## TODO (optimization): replace 'cat' by Perl-internal file reading?
    return `cat $safe_path`;
}


# no revision handling in plain file systems ....

sub revisions{
    return ();
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
