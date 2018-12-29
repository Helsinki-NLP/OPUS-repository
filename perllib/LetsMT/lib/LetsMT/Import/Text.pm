package LetsMT::Import::Text;

=head1 NAME

LetsMT::Import::Text

=head1 DESCRIPTION

A child of L<LetsMT::Import::Generic|LetsMT::Import::Generic>.

=cut

use strict;
use parent 'LetsMT::Import::Generic';

use Data::Dumper;
use File::Copy;
use File::Basename qw/dirname basename/;

use LetsMT::Tools;
use LetsMT::Import;
use LetsMT::Import::Generic;

use LetsMT::Lang::Encoding;
use LetsMT::Lang::Detect;
use LetsMT::Lang::ISO639;


=head1 CONSTRUCTOR

=cut

sub new {
    my $class = shift;
    my %self  = @_;
    $self{type}         = 'txt';             # we need a text reader!
    $self{type_pattern} = '(?:txt|text)';    # special pattern to convert res
    bless \%self, $class;
    return \%self;
}


=head1 METHODS

=head2 C<validate>

Text validation includes a conversion to UTF-8 if necessary.

Returns (\@err_resources, \@warn_resources, $logmessage)

=cut

sub validate {
    my $self = shift;
    my ($resource) = @_;

    my $file = $resource->local_path;
    my $lang = $resource->language();

    # Text::validate is special because it tries to convert a file to
    # utf8 if another character encoding is detected (or assumed)
    # --> operate on a tempfile to avoid overwriting the original file
    #     with text2utf8 (don't use text2utf8_inplace (anymore)
    # 
    # IMPORTANT: keep extension to handle compressed files correctly!
    # TODO: use a more generic tempfile name?!

    my $valid_file = dirname($file);
    $valid_file .= '/__TMP__'.basename($file);
    link( $file, $valid_file );

    # check if we can work with the encoding
    # - can be set in the resource object
    # - may be detected by BOM
    my $encoding = $resource->encoding()
        || LetsMT::Tools::get_bom_encoding($valid_file);

    # try to convert to UTF-8 if necessary
    if ( $encoding !~ /utf-?8/i ) {

	# try to detect encoding
	my $detected_encoding = &detect_encoding( $valid_file, $lang );
	if ( $detected_encoding !~ /utf-?8/i ) {

	    # try to convert the text file
	    unlink($valid_file);
	    unless ( &text2utf8( $file, $valid_file, undef, $lang ) ) {
		unlink($valid_file);
		return [ [ $resource, 
			   import_log => 'Failed to validate as text' ] ];
	    }
	}
    }

    # not a text? --> not OK!
    unless ( -T $valid_file ) {
	unlink($valid_file);
        return [ [ $resource, import_log => 'Failed to validate as text' ] ];
    }

    # success! --> move the tempfile over the original one
    # (for the case it was converted to utf8)
    move( $valid_file, $file );

    # extra call to unlink: linked files do not disappear otherwise
    unlink($valid_file) if (-e $valid_file); 

    return [];

    ## NEW: skip language check during validation
    ##      Why? because we check the language later in conversion
    # 
    # # no language known ---> don't need to check!
    # return [] unless ($lang);

    # # check language
    # my @detected = &detect_language($file);
    # return [] if ( $detected[0] eq 'unknown' );   # unknown --> let's trust it
    # return [] if ( grep( $_ eq $lang, @detected ) );   # one of the detected? -> OK!

    # # if the language does not match --> return a warn-resource
    # # (but do not fail!)
    # my $LangName = &iso639_ThreeToName( &iso639_TwoToThree($lang) );
    # return (
    #     [],
    #     [ [ $resource, detected_languages => join( ',', @detected ) ] ],
    #     "Failed to validate as $LangName text"
    # );

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
