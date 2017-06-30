package LetsMT::Repository::StorageManager::MySQL::Partition;

=head1 NAME

LetsMT::Repository::StorageManager::MySQL::Partition - persistent object class for LetsMT's StorageManager

=cut

use strict;
use parent 'LetsMT::Repository::Persist';

use Log::Log4perl qw(get_logger :levels);
use LetsMT::Repository::Safesys;
use LetsMT::Repository::Err;

my %persist_def = (
    fields => {
        name       => { type => 'varchar(128) NOT NULL',  prim      => 1 },
        diskname   => { type => 'varchar(128) NOT NULL' },
        mountpoint => { type => 'varchar(128) NOT NULL' },
        online     => { type => 'INT NOT NULL DEFAULT 0', transient => 1 }
    }
);
my @quote_attrs    = ( 'name', 'diskname', 'mountpoint' );
my @nonquote_attrs = ('online');
my @attrs          = ( @quote_attrs, @nonquote_attrs );

my $AVG_SLOT_SIZE = 10000;


=head1 CONSTRUCTOR

 $part = new LetsMT::Repository::StorageManager::MySQL::Partition ($name)

=cut

sub new {
    my ( $class, $name ) = @_;
    my $diskname = Safesys::safe_filesys_name($name) unless ( !$name );
    my $mountpoint = "/mnt/xyz";
    my $online = 1;                      # assume this is true...
    my $self   = $class->SUPER::new();

    map { $self->{$_} = $persist_def{$_} } keys %persist_def;

    eval { $self->SUPER::initialize(); };

    if ($@) { raise( 7, $@ . "partition $name" ) }

    if ($name) {
        raise( 4, "partition $diskname" )
            unless $self->init_instance( qq{name = '$name'},
            map { $_ => eval '$' . $_ } (@attrs) );
    }

    return $self;
}


=head1 METHODS

=head2 C<get_idquery>

 $sql = $part->get_idquery ($name)

Returns: an SQL query to be used by C<retrieve>.

=cut

sub make_idquery {
    my ( $self, $name ) = @_;
    return "name = '$name'";
}


=head2 C<select_part>

 $part->select_part ($size)

Select a suitable partition for Slot storage.
This is only a stub.

Returns: a path to a storage place on the file system.

=cut

sub select_part {
    my $size = shift;
    $size = $AVG_SLOT_SIZE unless ($size);

    my $default_part = defined( $ENV{STORAGE_PARTITION0} )
        ? $ENV{STORAGE_PARTITION0}
        : defined( $ENV{LETSMTDISKROOT} )
            ? $ENV{LETSMTDISKROOT}
            : "/tmp/fallbackdisk";

    if ( ! -d $default_part ) {
        system("mkdir -p $default_part") == 0 || raise(
            8, "mkdir -p $default_part"
        );
    }

    return $default_part;
}


=head1 CLASS METHOD

=head2 C<drop_table>

Drop the Partition table.

Returns: nothing.

=cut

sub drop_table {
    my $obj = new LetsMT::Repository::StorageManager::MySQL::Partition();
    $obj->SUPER::drop_table();
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