package LetsMT::Import::SRT;

=head1 NAME

LetsMT::Import::SRT - import handler for C<srt> files

=head1 DESCRIPTION

SRT: SubRip Text - a plain-text format for video subtitles.

A child of L<LetsMT::Import::Text|LetsMT::Import::Text>.

=cut


#----------------------------------------------------------------
#
# TODO: integrate Pierre Lison's improved conversion tool for srt2xml
#
#


use strict;
use parent 'LetsMT::Import::Text';

use LetsMT::Import;
use LetsMT::Import::Text;
use LetsMT::Lang::ISO639;
use LetsMT::Lang::Encoding qw/:all/;
use LetsMT::WebService;
use LetsMT::Tools;
use LetsMT::Repository::Err;


use File::Basename qw/dirname basename/;
use File::Temp qw(tempfile tempdir);
use File::Copy;


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

    ## make a temporary file to avoid problems in the external script
    my ( $fh, $tmpfile ) = tempfile(
	'srt2xml_XXXXXXXX',
	DIR    => $ENV{UPLOADDIR},
	SUFFIX => '.xml',
	UNLINK => 1
	);
    close($fh) or raise( 8, "Could not close file handle: $fh", 'error' );

    ## convert to UTF-8
    &text2utf8_inplace($input,undef,$lang);

    ## call the external srt2xml script
    my $tmptok = $tmpfile.'.tok';
    unless ( &pipe_out_cmd_quiet($tmptok,'srt2xml','-e','utf8','-l',$lang,'-r',$tmpfile,$input) ){
	raise( 8, $! ) 
    }

    # make a new resource for the tokenized XML
    my $new_tokenized = $new_resource->clone;
    $new_tokenized->base_path('tok');
    my $tokfile = $new_tokenized->local_path;

    # move the temporary files
    my $tokdir = dirname($tokfile);
    &run_cmd( 'mkdir', '-p', $tokdir );
    move( $tmpfile, $output ) || raise( 8, $! );
    move( $tmptok, $tokfile ) || raise( 8, $! );

    ## return both of the new resources
    return [
        {   resource => $new_resource,
            meta     => {
                # size            => $sid,
                'resource-type' => 'corpusfile',
                language        => $lang
            }
        },
        {   resource => $new_tokenized,
            meta     => {
                # size            => $sid,
                'resource-type' => 'tokenized corpusfile',
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
