package LetsMT::Import::XMLReader;

=head1 NAME

LetsMT::Import::TMXReader - reader for arbitrary XML files

=head1 DESCRIPTION


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


=head1 CONSTRUCTOR

 $handler = new LetsMT::Import::XMLReader (%OPTIONS)

OPTIONS:

 normalizer
 tokenizer
 resource

=cut

my %SKIP_TAGS = ();


sub new {
    my $class = shift;
    my %self  = @_;
    bless \%self, $class;

    $self{normalizer} = $LetsMT::Import::DEFAULT_NORMALIZER  unless ( defined $self{normalizer} );
    $self{tokenizer}  = $LetsMT::Import::DEFAULT_TOKENIZER   unless ( defined $self{tokenizer} );
    $self{splitter}   = $LetsMT::Import::DEFAULT_SPLITTER    unless ( defined $self{splitter} );
    $self{lang}       = $LetsMT::Import::DEFAULT_LANG        unless ( defined $self{lang} );

    $self{parser} = new XML::Parser(
        Handlers => {
            Start => \&handle_start,
            End   => \&handle_end,
            Char  => \&handle_char,
        }
    );

    $self{parser}{xml_data} = {
        seg          => ''
    };

    $self{id}     = 0;
    $self{buffer} = [];

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

    open ( $self->{fh}, '<', $resource->local_path );
    binmode( $self->{fh} );
    # $self->{fh}    = &LetsMT::Tools::open_bom_file( $resource->local_path );
    $self->{expat} = $self->{parser}->parse_start;
    return $self->{fh};
}


=head2 C<read>

Read XML and return an object with language data

Monolingual sentence "pair" structure:

 {
     lang => {
         id => [ token1, token2, ..., tokenN ]
     }
 }

markup structures:

 {
     lang => [
         "plain text",
         [open-tag, {attr1 => 1, ... } ],
         [close-tag],
     ]
 }

=cut

sub read {
    my $self = shift;
    my $before = shift || {};
    my $after = shift || {};

    unless ( scalar @{ $self->{buffer} } ) {

	## initialize with markup that came after previous segment
	my $lang = $self->{lang};
	if (ref($self->{after}) eq 'HASH') {
	    %{$self->{before}} = %{$self->{after}};
	}
	else{
	    $self->{before} = {};
	}
	$self->{before}{$lang} = [] unless (exists $self->{before}{$lang});
	$self->{after}         = {};
	$self->{after}{$lang}  = [];

	## link them to the parser object
	$self->{expat}{before}   = $self->{before}{$lang};
	$self->{expat}{after}    = $self->{after}{$lang};

	my $data = $self->{parser}{xml_data};
	my $line;

	while ( defined( $line = readline $self->{fh} ) ) {
	    # &clean_xml_no_copy($line);
	    $line=~s/$/ /;           # avoid putting lines together without space
	    eval { $self->{expat}->parse_more($line) || last; };
	    if ($@) {
		raise( 17, "xml document (error: $@)", 'warn' );
	    }
	    if ( $data->{seg_end} ){
		$self->{normalizer}->normalize_no_copy( $data->{seg} );
		if ($data->{seg}=~/\S/){
		    my @sentences = $self->{splitter}->split( $data->{seg} );
		    push @{ $self->{buffer} }, @sentences;
		    delete $data->{seg_end};
		    $data->{seg} = '';
		    last if ( scalar @{ $self->{buffer} } );
		}
	    }
	}
    }

    ## things in the buffer?
    ## ---> return the next sentence

    if ( scalar @{ $self->{buffer} } ) {
	$self->{id}++;
	%{$before} = %{$self->{before}};
	$self->{before} = {};
	return {
	    $self->{lang} => {
		$self->{id} => [
		    $self->{tokenizer}->tokenize( shift @{ $self->{buffer} } )
		    ]
	    }
	};
    }

    return undef;
}


=head2 C<close>

Gracefully tell the system that this reader will not be used to read any more.

=cut

sub close {
    my $self = shift;
    close $self->{fh} if (exists $self->{fh});
}


# ------------------------------------------------------------------------------
# Xml processing callback methods.
# ------------------------------------------------------------------------------

=head1 CLASS METHODS - XML processing callbacks

=head2 C<handle_start>

=cut

## TODO: keep before and after tags ....

sub handle_start {
    my ( $expat, $element, %atts ) = @_;

    if (lc($element) eq 'head') {
	$$expat{HEADER} = 1;
    }

    return if ( exists $SKIP_TAGS{$element} );

    push( @{$$expat{TAGS}}, $element );
    if ( $$expat{xml_data}{seg}=~/\S/ ){
	push( @{$expat->{after}},[ $element,{ %atts } ] );
	$$expat{xml_data}{seg_end} = 1;
    }
    else{
	push( @{$expat->{before}},[ $element,{ %atts } ] );
    }
}


=head2 C<handle_end>

=cut

sub handle_end {
    my ( $expat, $element ) = @_;

    if (lc($element) eq 'head') {
	delete $$expat{HEADER};
    }

    return if ( exists $SKIP_TAGS{$element} );

    pop( @{$$expat{TAGS}} );
    if ( $$expat{xml_data}{seg}=~/\S/ ){
	push( @{$expat->{after}},[ $element ] );
	$$expat{xml_data}{seg_end} = 1;
    }
    else{
	push( @{$expat->{before}},[ $element ] );
    }
}


=head2 C<handle_char>

=cut

sub handle_char {
    my ( $expat, $string ) = @_;

    if ($$expat{HEADER}){
	chomp( $string );
	push( @{$expat->{before}}, $string );
    }
    else{
	$$expat{xml_data}{seg} .= $string;
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
