package LetsMT::Repository::StorageManager::Slot;

=head1 NAME

LetsMT::Repository::StorageManager::Slot

=cut

use LetsMT;
use LetsMT::Repository::StorageManager::TC::Slot;

=head1 CONSTRUCTOR

=cut

# new simply returns either SlotMySQL or SlotTC objects
# depending on settings in LetsMT.pm

sub new {
    my $class = shift;

    if ( $LetsMT::RR_MANAGER_DBMS eq 'mysql' ) {
        require LetsMT::Repository::StorageManager::MySQL::Slot;
        return new LetsMT::Repository::StorageManager::MySQL::Slot(@_);
    }
    return new LetsMT::Repository::StorageManager::TC::Slot(@_);
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


=head2 C<drop_table>

=cut

sub drop_table {
    if ( $LetsMT::RR_MANAGER_DBMS eq 'mysql' ) {
        return LetsMT::Repository::StorageManager::MySQL::Slot::drop_table();
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