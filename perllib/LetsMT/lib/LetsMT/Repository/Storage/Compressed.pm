package LetsMT::Repository::Storage::Compressed;

=head1 NAME

LetsMT::Repository::Compressed - storage backend using a compressed file systemn

=head1 DESCRIPTION

This class is a child of 
L<LetsMT::Repository::Storage::FileSystem|LetsMT::Repository::Storage::FileSystem> and changes the DISKROOT (which should be mounted as a compressed filesystem using fusecompress)

=cut

use strict;
use parent 'LetsMT::Repository::Storage::FileSystem';

use open qw(:std :utf8);

use LetsMT;
use LetsMT::Repository::Storage::FileSystem;

use LetsMT::Tools;
use LetsMT::Repository::Err;

use Log::Log4perl qw(get_logger :levels);


=head1 CONSTRUCTOR

 $storage = new LetsMT::Repository::Storage::Compressed (%params);

=cut

sub new {
    my $class = shift;
    my %self  = @_;

    ## add another subdir in the LETSMTDISKROOTPATH
    ## (this shoulf be mounted as a compressed filesystem;
    ##  it will be used as a plain file system backend otherwise)

    my $rootdir = $ENV{LETSMTDISKROOT} || '/var/lib/user';
    my @dir = split(/\/+/,$rootdir);
    my $user = pop(@dir);
    push(@dir,'compressed',$user);

    $self{partition} = join('/',@dir);

    bless \%self, $class;
    return \%self;
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
