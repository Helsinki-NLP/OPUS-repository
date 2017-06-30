package LetsMT::Repository::Storage::AnyVC;

=head1 NAME

LetsMT::Repository::AnyVC - generic storage backend for a version controlled file system

=head1 DESCRIPTION

This module returns an object instance of the selected version-control-system backend (default = SVNServer)

=cut

use strict;

use LetsMT;
use LetsMT::Repository::Storage::SVNLocal;
use LetsMT::Repository::Storage::SVNServer;


=head1 CONSTRUCTOR

 $storage = new LetsMT::Repository::Storage::AnyVC (%params);

Return an instance of the selected VC-backend (or SVNServer).
Select the VC-backend with $params{vc} = <backend-name>

=cut

sub new {
    my $class = shift;
    my %self  = @_;

    if ($self{vc}=~/svn[-_]?(local|file)/){
	return new LetsMT::Repository::Storage::SVNLocal(@_);
    }
    return new LetsMT::Repository::Storage::SVNServer(@_);
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
