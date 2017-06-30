package LetsMT::Import::SRTsimple;

=head1 NAME

LetsMT::Import::SRTsimple - very simple import handler for C<srt> files

=head1 DESCRIPTION

SRT: SubRip Text - a plain-text format for video subtitles.

A simple child of L<LetsMT::Import::Text|LetsMT::Import::Text>.

=cut

use strict;
use parent 'LetsMT::Import::Text';

use Data::Dumper;


=head1 CONSTRUCTOR

=cut

sub new {
    my $class = shift;
    my %self  = @_;
    $self{type} = 'srt';    # we need an srt reader!
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