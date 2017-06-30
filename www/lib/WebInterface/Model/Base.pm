package WebInterface::Model::Base;
use strict;
use warnings;
use v5.10;
use base qw/Mojo::Base/;

#### Class Methods ####

sub select {
    my $class = shift;

    WebInterface::Model->db->select( $class->table_name, '*', @_ );
}

sub insert {
    my $class = shift;
    my $db    = WebInterface::Model->db;
    $db->insert( $class->table_name, @_ ) or die $db->error();
    $db->last_insert_id( '', '', '', '' ) or die $db->error();
}

sub update {
    my $class = shift;
    my $db    = WebInterface::Model->db;
    $db->update( $class->table_name, @_ ) or die $db->error();
}

sub delete {
    my $class = shift;
    my $db    = WebInterface::Model->db;
    $db->delete( $class->table_name, @_ ) or die $db->error();
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
