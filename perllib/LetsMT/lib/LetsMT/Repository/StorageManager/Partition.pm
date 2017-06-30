package LetsMT::Repository::StorageManager::Partition;

=head1 NAME

LetsMT::Repository::StorageManager::Partition;

=cut

use LetsMT;

my $AVG_SLOT_SIZE = 10000;


=head1 CONSTRUCTOR

=cut

# new simply returns either BranchMySQL or BranchTC objects
# depending on settings in LetsMT.pm

sub new {
    my $class = shift;

    if ( $LetsMT::RR_MANAGER_DBMS eq 'mysql' ) {
        require LetsMT::Repository::StorageManager::MySQL::Partition;
        return new LetsMT::Repository::StorageManager::MySQL::Partition(@_);
    }
    my %self = @_;
    return bless \%self, $class;
}


=head1 METHODS

=head2 C<get_idquery>

=cut

# for compatibility: provide non-object method get_idquery
# by calling the object method make_idquery

sub get_idquery {
    my $obj = new LetsMT::Repository::StorageManager::Slot();
    return $obj->get_idquery(@_);
}


=head2 C<select_part>

 select_part ($size)

Return a suitable partition for Slot storage.
This is only a stub.

Returns: a path to a storage place on the file system.

=cut

sub select_part {
    my $size = shift;
    $size = $AVG_SLOT_SIZE unless ($size);

    my $default_part
        = defined( $ENV{STORAGE_PARTITION0} ) ? $ENV{STORAGE_PARTITION0}
        : defined( $ENV{LETSMTDISKROOT} )     ? $ENV{LETSMTDISKROOT}
        :                                       "/tmp/fallbackdisk";

    if ( !-d $default_part ) {
        system("mkdir -p $default_part") == 0
            || raise( 8, "mkdir -p $default_part" );
    }

    return $default_part;
}


=head2 C<drop_table>

=cut

sub drop_table {
    if ( $LetsMT::RR_MANAGER_DBMS eq 'mysql' ) {
        return
            LetsMT::Repository::StorageManager::MySQL::Partition::drop_table(
            );
    }
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