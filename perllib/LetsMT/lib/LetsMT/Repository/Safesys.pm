package LetsMT::Repository::Safesys;

=head1 NAME

LetsMT::Repository::Safesys - tools for interacting with the operating system

=cut

use strict;

use open qw(:std :utf8);

use Filesys::DiskUsage qw(du);
use POSIX qw(strftime);
use File::Temp;

use Log::Log4perl qw(get_logger :levels);


=head1 FUNCTIONS

=head1 C<sys>

 $status = &sys ($cmd)

Execute a command using system() and log the call.

Returns: exit status of system().

=cut

sub sys {
    get_logger(__PACKAGE__)->debug( join( ' ', @_ ) );

    my $ret;
    eval { $ret = system(@_); };

    raise( 8, 'system call failed: ' . $@, 'error' ) if ($@);
    get_logger(__PACKAGE__)->info("system call returned '$ret'") if ($ret);

    return $ret;
}


=head1 C<safe_filesys_name>

 $safename = &safe_filesys_name ($name)

Remove unsafe characters from a file name.

Returns: the "safeified" filename.

=cut

sub safe_filesys_name {
    my ($name) = @_;

    #  $name = lc($name);
    $name =~ s/\s+/_/g;
    $name =~ s/[_]+/_/g;
    $name =~ s/[^A-Za-z0-9\/_]//g;
    return $name;
}


=head1 C<safe_filesys_unique_name>

 $uniquename = &safe_filesys_unique_name ($name)

Create a safe filename, then find a unique permutation of it.

Returns: a unique, safe filename.

=cut

sub safe_filesys_unique_name {
    my ($name) = @_;

    $name = &safe_filesys_name($name);
    return $name unless ( -f $name );

    my $i = 1;
    while ( -f $name . $i ) {
        $i++;
    }

    return $name . $i;
}


=head1 C<safe_du>

 $size = &safe_du ($dir)

Compute the disk usage of a directory.

Returns: the size on disk of the directory.

=cut

sub safe_du {
    my $dir = shift;

    return du( { "human-readable" => 0, recursive => 1 }, $dir );
}


=head1 C<time>

Format a time string.

Returns: a nicely formatted time string

=cut

sub time {
    return strftime( "%F %T", gmtime( time() ) );
}


=head1 C<get_tempdir>

 $dir = &get_tempdir

Create a temporary directory.

Returns: a new temporary directory, which will be cleaned up by Perl on exit.

=cut

sub get_tempdir {
    return tempdir(
        'safesys_XXXXXXXX',
        DIR     => '/tmp',
        CLEANUP => 1,
    );
}


=head1 C<sql_escape>

 sql_escape ($list)

Try to create a safe SQL string from a list of strings.

Returns: a safe SQL string.

=cut

sub sql_escape {
    my $list = shift;

    return scalar join( ',', map { "'" . quotemeta($_) . "'" } @{$list} );
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