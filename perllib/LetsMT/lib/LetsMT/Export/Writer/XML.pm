package LetsMT::Export::Writer::XML;

#
# TODO: shouldn't this be done using XML::Writer?
#


=head1 NAME

LetsMT::Export::Writer::XML

=head1 DESCRIPTION

A child of L<LetsMT::Export::Writer::Text|LetsMT::Export::Writer::Text>,
see there for most documentation.

=cut

use strict;
use parent 'LetsMT::Export::Writer::Text';


=head1 METHODS

=head2 C<markup_to_string>

Create some additional markup (can be before or after the actual sentences).

=cut

sub markup_to_string {
    my $self = shift;
    my $markup = shift || [];

    my $string = '';
    foreach my $e ( @{$markup} ) {
        if ( ref($e) eq 'ARRAY' ) {    # it's a tag (and not text)
            my $tag = shift( @{$e} );    # this is the tag
            if ( @{$e} ) {               # it's an opening tag
                push( @{ $self->{OPENTAGS} }, $tag );
                my $attr = $$e[0];
                $string .= '<' . $tag;
                foreach ( keys %{$attr} ) {
                    $string .= ' ' . $self->_key_encode($_);
                    $string .= '="' . $self->_attr_encode( $$attr{$_} ) . '"';
                }
                $string .= ">";
                # $string .= ">\n";
            }
            else {
                if ( @{ $$self{OPENTAGS} }
                    && ( $$self{OPENTAGS}[-1] eq $tag ) )
                {
                    pop( @{ $$self{OPENTAGS} } );
                }

                # else { print STDERR "mismatch!!!!!"; }
                $string .= '</' . $tag . ">\n";
            }
        }
        else {
            $string .= $self->_encode($e);
        }
    }
    if ($string){
	chomp $string;
	$string .= "\n";
    }
    return $string;
}


=head2 C<_header>

=cut

#
# should put some more information into the header
# meta-data like
# -language
# - creation time
# - source
# - domain
# ....
#

sub _header {
    #    my $self=shift;
    return '<?xml version="1.0" encoding="utf-8"?>
<letsmt version="1.0">
';
}

# <head></head>
# <body>


=head2 C<_close_open_tags>

Recursively close all tags that are still open.

=cut

sub _close_open_tags {
    my $self   = shift;
    my $string = '';
    while ( my $tag = pop( @{ $self->{OPENTAGS} } ) ) {
        $string .= '</' . $tag . ">\n";
    }
    return $string;
}


=head2 C<tail>

Close all open tags, then close the body and the C<letsmt> XML.

=cut

sub _tail {
    my $self = shift;
    return $self->_close_open_tags() . '</letsmt>'."\n";
#    return $self->_close_open_tags() . '</body>
# </letsmt>
# ';
}


=head2 C<_sentence_start>

=cut

# print a single sentence to an open filehandle
#
# dependening on the type of data this will
#  - print a tokenized sentence (using <w> tags)
#  - possibly with attributes (_print_token)
#  - or a tree structure (Tiger format - not implemented yet)
#  - or a plain text sentence

## TODO: this should be better done with XML::Writer
##       --> completely remanufacture this?!

sub _sentence_start {
    my ( $self, $id, $attr ) = @_;
    $id = $self->{SID} unless ($id);
    if (ref($attr) eq 'HASH'){
	my $str = "<s id=\"$id\"";
	foreach my $k (sort keys %{$attr}){
	    $str .= ' '.$k.'="'.$self->_encode($$attr{$k}).'"';
	}
	return $str.'>';
    }
    return "<s id=\"$id\">";
}


=head2 C<_sentence_end>

=cut

sub _sentence_end {
    my ( $self, $id ) = @_;
    return "</s>";
}


=head2 C<_tokenized>

=cut

sub _tokenized {
    my ( $self, $data, $id ) = @_;
    my $str = $self->_sentence_start($id);
    $str .= "\n";
    foreach my $token ( @{$data} ) {
        if ( ref($token) eq 'HASH' ) {
            $str .= $self->_token($token);
        }
        else {

      #
      # skip markup with <w> if there are no extra attributes
      # --> simply use ' ' as delimiter
      # --> avoids <w> tags for non-tokenized texts coming from Import-Readers
      #
      #            $str .= " <w>";
            $str .= $self->_encode($token) . ' ';

            #            $str .= "</w>\n";
        }
    }
    $str =~ s/ $//;
    $str .= $self->_sentence_end($id);
    return $str;
}


=head2 C<_token>

=cut

# print token prints a token with various attributes
# attribute 'word' = actual token

sub _token {
    my ( $self, $token ) = @_;
    my $str = '<w';
    foreach my $k ( keys %{$token} ) {
        next if ( $k eq 'word' );
        $str .= ' ' . $k . '="';
        $str .= $self->_encode( $token->{$k} );
        $str .= '"';
    }
    if ( exists $token->{word} ) {
        $str .= ">";
        $str .= $token->{word};
        $str .= "</w>\n";
    }
    else { $str .= " />\n"; }
    return $str;
}


=head2 C<_print_tree>

** Not implemented yet
(will be parse trees in TigerXML).

=cut

sub _print_tree {
    my ( $self, $data ) = @_;
}



## TODO: better use some explicit XML writer?
## (or do some better checking of strings, non-printable characters etc)

=head2 C<_encode>

Encode strings

=cut

sub _encode {
    $_[1] =~ s/\&/&amp;/gs;
    $_[1] =~ s/\</&lt;/gs;
    $_[1] =~ s/\>/&gt;/gs;
#    $_[1] =~ s/\"/&quot;/gs;
    return $_[1];
}

=head2 C<_attr_encode>

Encode string in attribute values

=cut

sub _attr_encode {
    $_[1] =~ s/\&/&amp;/gs;
    $_[1] =~ s/\</&lt;/gs;
    $_[1] =~ s/\>/&gt;/gs;
    $_[1] =~ s/\"/&quot;/gs;
    return $_[1];
}


=head2 C<_key_encode>

Encode tag-attribute keys:
only allow basic ascii characters!

=cut

sub _key_encode {
    $_[1] =~ s/[^a-zA-Z\_\-0-9]/\_/gs;
    return $_[1];
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
