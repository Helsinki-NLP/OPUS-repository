package LetsMT::Repository::Storage::VCxml;

=head1 NAME

LetsMT::Repository::VCxml - storage backend for a version controlled file system for the xml-subdirectory only with a working copy in a compressed file system

=head1 DESCRIPTION

This storage backend keeps a working copy (using the compressed filesystem backend) but also handles a version-controlled repository using AnyVC but ONLY for the 'xml' sub-directory

=cut


## TODO: does it really work or does it still commit everything to the VC backend?


use strict;
use parent 'LetsMT::Repository::Storage::VC';

use LetsMT;
use LetsMT::Repository::Storage::VC;


# internal method: commit all changes from the working copy in the xml dir

sub _commit_changes {
    my $self = shift;
    my ( $repos, $branch, $user ) = @_;
    $self->_goto_root( $repos );
    # make sure everything is added
    $self->{VC}->add_file( $user, $branch.'/xml'  ); 
    # commit all changes to the central repository
    my $ret=$self->{VC}->commit($user, $branch, 'commit all changes');
    $self->_come_back();
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
