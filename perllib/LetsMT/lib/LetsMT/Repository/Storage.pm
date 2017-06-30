package LetsMT::Repository::Storage;

=head1 NAME

LetsMT::Repository::Storage - abstract class for storage in version-control systems

=cut

use strict;

use open qw(:std :utf8);

use LetsMT::Repository::Storage::SVNLocal;       # local svn repositories (don't use!)
use LetsMT::Repository::Storage::SVNServer;      # svn server on localhost
use LetsMT::Repository::Storage::FileSystem;     # plain file system
use LetsMT::Repository::Storage::Compressed;     # compressed file system (using fusecompress)
use LetsMT::Repository::Storage::AnyVC;          # any version-control system
use LetsMT::Repository::Storage::VC;             # a version control system with working copy
use LetsMT::Repository::Storage::VCxml;          # like VC but only xml dir in version control
use LetsMT::Repository::Storage::VCxml;

use Log::Log4perl qw(get_logger :levels);


=head1 DESCRIPTION

Implemented backends:

 svn_local  (aliases: svn_file, VCSubversion, VCSubersionLocal)
 svn_server (alias:   VCSubversionServer)
 filesystem
 compressed
 any_vc
 vc

=cut

our %BACKENDS = (
    svn_local  => 'LetsMT::Repository::Storage::SVNLocal',
    svn_server => 'LetsMT::Repository::Storage::SVNServer',
    filesystem => 'LetsMT::Repository::Storage::FileSystem',
    compressed => 'LetsMT::Repository::Storage::Compressed',
    any_vc     => 'LetsMT::Repository::Storage::AnyVC',
    vc         => 'LetsMT::Repository::Storage::VC',
    vc_xml     => 'LetsMT::Repository::Storage::VCxml',
);

# aliases
$BACKENDS{svn_file}           = $BACKENDS{svn_local};
$BACKENDS{VCSubversion}       = $BACKENDS{svn_local};
$BACKENDS{VCSubversionLocal}  = $BACKENDS{svn_local};
$BACKENDS{VCSubversionServer} = $BACKENDS{svn_server};
$BACKENDS{fusecompress}       = $BACKENDS{compressed};
$BACKENDS{AnyVC}              = $BACKENDS{any_vc};
$BACKENDS{VC}                 = $BACKENDS{vc};
$BACKENDS{VCxml}              = $BACKENDS{vc_xml};
$BACKENDS{xml_vc}             = $BACKENDS{vc_xml};
$BACKENDS{xmlVC}              = $BACKENDS{vc_xml};

=head1 CONSTRUCTOR / FACTORY METHOD

 $storage = new LetsMT::Repository::Storage ($type, $resource [, $format])

Return an appropriate reader object for a given resource C<$resource>.
The data format C<$format> is optional.
The constructor tries to infer the data from the resource object
if C<$format> is not specified (see L<LetsMT::Resource>::type).

=cut

sub new {
    my $class = shift;
    my $type  = shift;
    $type = $ENV{VC_BACKEND} unless ( exists $BACKENDS{$type} );
    return $BACKENDS{$type}->new(@_);
}


# methods defined for storage objects:

sub init    { return 0; }
sub mkdir   { return 0; }
sub is_path { return 0; }
sub update  { return 0; }
sub add     { return 0; }
sub copy    { return 0; }
sub cat     { return 0; }
sub list    { return 0; }
sub export  { return 0; }
sub remove  { return 0; }

# additional methods used in VC backends

sub add_file { return 0; }
sub commit   { return 0; }
sub checkout { return 0; }
sub revisions{ return 0; }


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
