package LetsMT::Repository::AdminManager;

=head1 NAME

LetsMT::Repository::AdminManager - administration manager

=head1 METHODS

=cut

use strict;

use open qw(:std :utf8);

use LetsMT::Repository::GroupManager;
use LetsMT::Repository::StorageManager;
use LetsMT::Repository::MetaManager;

use Data::Dumper;
use Log::Log4perl qw(get_logger :levels);
use LetsMT::Repository::Err;


=head1 FUNCTIONS

=head2 C<svnpath>

 &svnpath ($slot, $rest)

Converts a slot name and a path to a Subversion path.

Returns: writes string with subversion path into $result variable.

=cut

sub svnpath {
    my ( $result, $slot, $rest ) = @_;

    my $slotobj
        = &LetsMT::Repository::StorageManager::_get_slot( name => $slot );

    if ($slotobj) {
        my $tmp_result = [];
        do {
            my $tmp_hash = {
                'kind'    => 'svn path',
                'content' => 'file://'
                    . $slotobj->partition
                    . $slotobj->diskname . '/'
                    . $rest,
            };

            push( @$tmp_result, $tmp_hash );
        } while ( $slotobj->restore_next() );

        $$result = {
            'path'  => 'file:///' . join( '/', $slot, $rest ),
            'entry' => $tmp_result,
        };

        return 1;
    }

    raise( 6, "slot $slot", 'warn' );
}


=head2 C<db_status>

=cut

sub db_status {
    my ($result) = @_;

    my $db          = new LetsMT::Repository::MetaManager::TokyoCabinet();
    my $status_hash = $db->inform;

    get_logger(__PACKAGE__)->debug( Dumper($status_hash) );

    $$result = {
        'path'  => $status_hash->{'path'}[0],
        'entry' => [$status_hash],
    };
}



=head2 C<meta_db>

=cut

sub meta_db {
    my ($result, $command, %args ) = @_;

    my $db = new LetsMT::Repository::MetaManager;

    if ($command=~/^(optimize|add_index|delete_index|optimize_index)$/){
	my $ret = $db->$1( %args );
	$$result = { 'path'  => '', 'entry' => [ $ret ]};
    }
}



=head2 C<group_db>

=cut

sub group_db {
    my ($result, $command, %args ) = @_;

    my $db = new LetsMT::Repository::GroupManager::GroupDB;

    if ($command=~/^(optimize|add_index|delete_index|optimize_index)$/){
	my $ret = $db->$1( %args );
	$$result = { 'path'  => '', 'entry' => [ $ret ]};
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
