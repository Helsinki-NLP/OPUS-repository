package LetsMT::Import::XLIFFReader;

=head1 NAME

LetsMT::Import::XLIFFReader - reader for XLIFF files

=head1 DESCRIPTION

XLIFFF: the XML Localization Interchange File Format.

=cut

use strict;

use XML::Parser;
use Data::Dumper;
use Log::Log4perl qw(get_logger :levels);

use LetsMT;
use LetsMT::Lang::ISO639;
use LetsMT::Import;
use LetsMT::Import::TMXReader;
use LetsMT::WebService;
use LetsMT::Tools::XML qw/:all/;

=head1 CLASS VARIABLE (internal)

=head2 Tags

Tags can be either extracted or ignored.
The class variable C<$TAG_TO_CONCEPT> maps tmx-tags to keys that the reader can use.
If the reader hans any such key set to a C<true> value, the tags will be visible.
They are thus ignoed by default.
All tags mapped for L<TMX|LetsMT::Importer::TMXReader> are also mapped for XLIFF .

=cut

my $TAG_TO_CONCEPT = {};

# Use all tmx tags since xliff allows them.
while ( my ( $key, $value )
    = each %$LetsMT::Importer::TMXReader::TAG_TO_CONCEPT )
{
    $TAG_TO_CONCEPT->{$key} = $value;
}


=head1 CONSTRUCTOR

=cut

sub new {
    my $class = shift;
    my %self  = @_;
    bless \%self, $class;

    $self{normalizer} = $LetsMT::Import::DEFAULT_NORMALIZER
        unless ( defined $self{normalizer} );
    $self{tokenizer} = $LetsMT::Import::DEFAULT_TOKENIZER
        unless ( defined $self{tokenizer} );

    my $escape_lookup
        = &LetsMT::Tools::build_lookup_func( $TAG_TO_CONCEPT, '^', '$' );

    $self{parser} = new XML::Parser(
        Handlers => {
            Start => \&handle_start,
            End   => \&handle_end,
            Char  => \&handle_char,
        }
    );

    $self{parser}{xliff_data} = {
        escape      => 0,
        sent_pairs  => [],
        source_lang => '',
        target_lang => '',
        sid         => 0,
        seg         => '',
        in_seg      => 0,
        normalizer  => $self{normalizer},
        tokenizer   => $self{tokenizer},
        escape_func =>
            sub { return defined( $self{ $escape_lookup->( $_[0] ) } ); }
    };

    return \%self;
}


=head1 METHODS

=head2 C<open>

=cut

sub open {
    my $self = shift;
    my $resource = shift || $self->{resource};

    # Get requested resource if necessary
    if ( ( !-e $resource->local_path ) || $self->{-always_fetch} ) {
        return 0 unless ( &LetsMT::WebService::get_resource($resource) );
    }

    $self->{fh}    = &LetsMT::Tools::open_bom_file( $resource->local_path );
    $self->{expat} = $self->{parser}->parse_start;
    return $self->{fh};
}


=head2 C<read>

Read one translation unit from the open xliff-file.

Returns a reference to a translation unit or C<undef>.
A translation unit always has the format:

 {
     lang1 => {
         id1 => [ token1, token2, ..., tokenN ],
         id2 => [ token1, token2, ..., tokenN ],
         ...
     },
     lang2 => {
         id1 => [ token1, token2, ..., tokenN ],
         id2 => [ token1, token2, ..., tokenN ],
         ...
     },
     ...
 }

=cut

sub read {
    my $self = shift;
    my $data = $self->{parser}{xliff_data};

    my $line;

    # Loop conditions (for reading more lines):
    #   If there is data in the buffer the first is not finished
    #   There is more data to process
    while ( !( @{ $data->{sent_pairs} } && $data->{sent_pairs}[0]{finished} )
        && defined( $line = readline $self->{fh} ) )
    {
        clean_xml_no_copy($line);
	$line=~s/$/ /;           # avoid putting lines together without space
        $self->{expat}->parse_more($line) || last;
    }

    if ( @{ $data->{sent_pairs} } ) {
        my $sent_pair = shift @{ $data->{sent_pairs} };
        unless ( delete $sent_pair->{finished} ) {
            get_logger(__PACKAGE__)
                ->warn( "Partial translation unit discovered\n",
                Dumper($sent_pair) );
        }
        return $sent_pair;
    }
    else {
        return undef;
    }
}


=head2 C<close>

=cut

sub close {
    my $self = shift;
    close $self->{fh};
}



# ------------------------------------------------------------------------------
# XML-handlers
# ------------------------------------------------------------------------------

=head1 CLASS METHODS - XML processing callbacks

=head2 C<handle_start>

=cut

sub handle_start {
    my ( $expat, $element, %atts ) = @_;
    my $data = $expat->{xliff_data};
    if ( $data->{escape_func}->($element) ) {
        $data->{escape}++;
    }
    else {
        if ( $element eq 'trans-unit' ) {
            push @{ $data->{sent_pairs} }, {};
            $data->{sid}++;
        }
        elsif ( $element eq 'source' ) {
            $data->{in_seg} = 1;
        }
        elsif ( $element eq 'target' ) {
            $data->{in_seg} = 1;
        }
        elsif ( $element eq 'file' ) {
            $data->{source_lang} = &LetsMT::Lang::ISO639::iso639_AnyToTwo(
                $atts{'source-language'} );
            $data->{target_lang} = &LetsMT::Lang::ISO639::iso639_AnyToTwo(
                $atts{'target-language'} );
        }
    }
}


=head2 C<handle_end>

=cut

sub handle_end {
    my ( $expat, $element ) = @_;
    my $data = $expat->{xliff_data};

    if ( $data->{escape_func}->($element) ) {
        $data->{escape}--;
    }
    else {
        if ( $element eq 'trans-unit' ) {
            $data->{sent_pairs}[-1]{finished} = 1;
        }
        elsif ( $element eq 'source' ) {

            # normalize source text
            $data->{normalizer}->normalize_no_copy( $data->{seg} );

            # tokenize source text
            $data->{sent_pairs}[-1]{ $data->{source_lang} }{ $data->{sid} }
                = [ $data->{tokenizer}->tokenize( $data->{seg} ) ];
            $data->{seg}    = '';
            $data->{in_seg} = 0;
        }
        elsif ( $element eq 'target' ) {
            # normalize target text
            $data->{normalizer}->normalize_no_copy( $data->{seg} );

            # tokenize target text
            $data->{sent_pairs}[-1]{ $data->{target_lang} }{ $data->{sid} }
                = [ $data->{tokenizer}->tokenize( $data->{seg} ) ];
            $data->{seg}    = '';
            $data->{in_seg} = 0;
        }
    }
}


=head2 C<handle_char>

=cut

sub handle_char {
    my ( $expat, $string ) = @_;
    my $data = $expat->{xliff_data};
    if ( $data->{in_seg} && !$data->{escape} ) {
        $data->{seg} .= $string;
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
