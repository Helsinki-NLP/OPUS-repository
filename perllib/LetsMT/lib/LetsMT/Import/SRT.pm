package LetsMT::Import::SRT;

=head1 NAME

LetsMT::Import::SRT - import handler for C<srt> files

=head1 DESCRIPTION

SRT: SubRip Text - a plain-text format for video subtitles.

A child of L<LetsMT::Import::Text|LetsMT::Import::Text>.

=cut

use strict;
use parent 'LetsMT::Import::Text';

use LetsMT::Import;
use LetsMT::Import::Text;
use LetsMT::Lang::ISO639;
use LetsMT::WebService;
use LetsMT::Tools;

use File::Basename qw/dirname basename/;

=head1 CONSTRUCTOR

=cut

sub new {
    my $class = shift;
    my %self  = @_;
    $self{type} = 'srt';    # we need an srt reader!
    bless \%self, $class;
    return \%self;
}



=head1 METHOD

=head2 C<convert>

=cut

sub convert {
    my $self = shift;
    my ( $resource, $importer, $meta_resource ) = @_;

    my $type_pattern = $self->{type_pattern} || $self->{type};
    my $new_resource = $resource->convert_type( $type_pattern, 'xml' );

    # shift the 'uploads' path to local_dir
    $new_resource->shift_path_to_local();

    ## TODO adjust these parameters ....

    my $lang = $resource->language();


    my $input = $resource->local_path;
    my $output = $new_resource->local_path;

    my $dirname = dirname($output);
    &run_cmd( 'mkdir', '-p', $dirname );
    &run_cmd( 'dos2unix', $input );
    &run_cmd( 'srt2xml','-l',$lang,'-r',$output,'<',$input,'>',$output.'.tok' );

    return [
        {   resource => $new_resource,
            meta     => {
                # size            => $sid,
                'resource-type' => 'corpusfile',
                language        => $lang
            }
        }
    ];
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
