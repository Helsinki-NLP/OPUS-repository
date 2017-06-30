package LetsMT::Import::TMXReader;

=head1 NAME

LetsMT::Import::TMXReader - reader for TMX files

=head1 DESCRIPTION

TMX: the Translation Memory eXchange format.

=cut

use strict;

use XML::Parser;
use Data::Dumper;
use Log::Log4perl qw(get_logger :levels);

use LetsMT;
use LetsMT::Lang::ISO639;
use LetsMT::Import;
use LetsMT::Repository::Err;
use LetsMT::WebService;
use LetsMT::Tools::XML;

=head1 CLASS VARIABLE (internal)

=head2 Tags

Tags can be either extracted or ignored.
The class variable C<$TAG_TO_CONCEPT> maps tmx-tags to keys that the reader can use.
If the reader hans any such key set to a C<true> value, the tags will be visible.
They are thus ignored by default.

=cut

my $TAG_TO_CONCEPT = {
    bpt => '-inline',
    ph  => '-placeholder',
    it  => '-highlight',
    hi  => '-highlight',
};


=head1 CONSTRUCTOR

 $handler = new LetsMT::Import::TMXReader (%OPTIONS)

OPTIONS:

 normalizer
 tokenizer
 resource

=cut

sub new {
    my $class = shift;
    my %self  = @_;
    bless \%self, $class;

    $self{normalizer} = $LetsMT::Import::DEFAULT_NORMALIZER  unless ( defined $self{normalizer} );
    $self{tokenizer}  = $LetsMT::Import::DEFAULT_TOKENIZER   unless ( defined $self{tokenizer} );

    my $escape_lookup
        = &LetsMT::Tools::build_lookup_func( $TAG_TO_CONCEPT, '^', '$' );

    $self{parser} = new XML::Parser(
        Handlers => {
            Start => \&handle_start,
            End   => \&handle_end,
            Char  => \&handle_char,
        }
    );

    $self{parser}{tmx_data} = {
        escape       => 0,
        sent_pairs   => [],
        current_lang => 0,
        sid          => 0,
        seg          => '',
        in_seg       => 0,
        normalizer   => $self{normalizer},
        tokenizer    => $self{tokenizer},
        escape_func =>
            sub { return defined( $self{ $escape_lookup->( $_[0] ) } ); }
    };

    return \%self;
}


=head2 C<open>

 $handler->open ($resource)

Open the C<$resource> for reading.

 $handler->open

C<$resource> can also have been passed as an option to the constructor.

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

Read one translation unit from the open tmx-file. Returns a reference to a
translation unit or C<undef>. A translation unit always has the format:

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
    my $data = $self->{parser}{tmx_data};

    my $line;

    # Loop conditions:
    #   If there is data in the buffer the first is not finished
    #   There is more data to process
    while ( !( @{ $data->{sent_pairs} } && $data->{sent_pairs}[0]{finished} )
        && defined( $line = readline $self->{fh} ) )
    {
        &clean_xml_no_copy($line);
	$line=~s/$/ /;           # avoid putting lines together without space
        eval { $self->{expat}->parse_more($line) || last; };
        if ($@) {
            raise( 17, "tmx document (error: $@)", 'warn' );
        }
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

Gracefully tell the system that this reader will not be used to read any more.

=cut

sub close {
    my $self = shift;
    close $self->{fh};
}


# ------------------------------------------------------------------------------
# Xml processing callback methods.
# ------------------------------------------------------------------------------

=head1 CLASS METHODS - XML processing callbacks

=head2 C<handle_start>

=cut

sub handle_start {
    my ( $expat, $element, %atts ) = @_;
    my $data = $expat->{tmx_data};
    if ( $data->{escape_func}->($element) ) {
        $data->{escape}++;
    }
    else {
        if ( $element eq 'tu' ) {
            $expat->{tu} = 1;
            push @{ $data->{sent_pairs} }, {};
            $data->{sid}++;
        }
        elsif ( $element eq 'tuv' ) {
            if ( $expat->{tu} ) {
                $expat->{tuv} = 1;

                # Cheat and let people get away with skipping the prefix
                # 'xml:' for the lang attribute.
                $atts{'xml:lang'} = $atts{lang}
                    unless ( defined $atts{'xml:lang'} );
                $data->{current_lang}
                    = lc(&LetsMT::Lang::ISO639::iso639_AnyToTwo(
			      $atts{'xml:lang'} ));
            }
        }
        elsif ( $element eq 'seg' ) {
            $data->{in_seg} = 1;
        }
    }
}


=head2 C<handle_end>

=cut

sub handle_end {
    my ( $expat, $element ) = @_;
    my $data = $expat->{tmx_data};

    if ( $data->{escape_func}->($element) ) {
        $data->{escape}--;
    }
    else {
        if ( $element eq 'tu' ) {
            delete $expat->{tu};
            $data->{sent_pairs}[-1]{finished} = 1;
        }
        elsif ( $element eq 'tuv' ) {
            if ( $expat->{tu} ) {
                delete $expat->{tuv};

                # normalize text
                $data->{normalizer}->normalize_no_copy( $data->{seg} );

                # tokenize text
                $data->{sent_pairs}[-1]{ $data->{current_lang} }
                    { $data->{sid} }
                    = [ $data->{tokenizer}->tokenize( $data->{seg} ) ];
                $data->{seg} = '';
            }
        }
        elsif ( $element eq 'seg' ) {
            $data->{in_seg} = 0;
        }
    }
}


=head2 C<handle_char>

=cut

sub handle_char {
    my ( $expat, $string ) = @_;
    my $data = $expat->{tmx_data};
    if ( $expat->{tuv} ) {
        if ( $data->{in_seg} && !$data->{escape} ) {
            $data->{seg} .= $string;
        }
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
