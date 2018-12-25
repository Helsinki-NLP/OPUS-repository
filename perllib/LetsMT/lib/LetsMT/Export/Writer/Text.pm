package LetsMT::Export::Writer::Text;

=head1 NAME

LetsMT::Export::Writer::Text - writer for plain-text files

=cut

use strict;
use parent 'LetsMT::Export::Writer';  # inherit get_resources method

use LetsMT::Resource;
use LetsMT::Tools;

use File::Path;
use File::Basename;


=head1 CONSTRUCTOR

Enforces 'utf8' encoding.

=cut

sub new {
    my $class = shift;
    my %self = ( -encoding => 'utf8', @_ );

    bless \%self, $class;
    return \%self;
}


=head1 METHODS

=head2 C<open>

 $writer->open ($resource, %params)

=cut

sub open {
    my $self     = shift;
    my $resource = shift || $self->{resource};
    my %para     = @_;

    # set additional parameters
    foreach ( keys %para ) { $self->{$_} = $para{$_}; }

    $self->{OPENTAGS} = [];

    $self->{SID} = 0;
    &File::Path::make_path( dirname( $resource->local_path ) );
    $self->{FH} = &LetsMT::Tools::open_out_file( $resource->local_path,
        $self->{-encoding} );
    my $fh = $self->{FH};
    print $fh $self->_header() if ($fh);
    return $fh;
}


=head2 C<close>

=cut

sub close {
    my $self = shift;
    my $fh   = $self->{FH};
    if ($fh) {
        print $fh $self->_tail();
        return $fh->close;
    }
    return undef;
}


=head2 C<write>

=cut

sub write {
    my $self = shift;
    my $data = shift;

    my $before = shift || {};
    my $after  = shift || {};
    my $attr   = shift || {};  # optional sentence attributes

    my $fh = $self->{FH};
    if ( ref($data) eq 'HASH' ) {
        foreach my $l ( keys %{$data} ) {
            print $fh $self->markup_to_string( $$before{$l} );
            print $fh $self->to_string( $$data{$l}, $$attr{$l} );
            print $fh $self->markup_to_string( $$after{$l} );
        }
    }
}


=head2 C<write_string>

=cut

sub write_string {
    my $self = shift;
    my $str  = shift;

    my $fh = $self->{FH};
    print $fh $str;
}


=head2 C<to_string>

=cut

sub to_string {
    my $self = shift;
    my $data = shift;
    my $attr = shift;   # optional sentence attributes

    my $str = '';

    my @ids = ();
    if ( ref($data) eq 'ARRAY' ) {    # array of sentences!
	$attr = [] unless ( ref($attr) eq 'ARRAY' );
        foreach my $s (0..$#{$data}) {
            $self->{SID}++;
            $self->{INFO}->{'size'}++;
            push( @ids, $self->{SID} );
            $str .= $self->_sentence( $$data[$s], $self->{SID}, $$attr[$s] ) . ' ';
        }
        $str =~ s/ $//;    # delete final space again
    }
    elsif ( ref($data) eq 'HASH' ) {    # hash of sentences (key = ID)
	$attr = {} unless ( ref($attr) eq 'HASH' );
	## TODO: is sort the best way to do here?
	##       does this always give the correct order?
        foreach my $id ( sort {$a <=> $b } keys %{$data} ) {
            $self->{SID}++;             # count anyway
            $self->{INFO}->{'size'}++;
            push( @ids, $id );
            $str .= $self->_sentence( $data->{$id}, $id, $attr->{$id} ) . ' ';
        }
        $str =~ s/ $//;    # delete final space again
    }
    else {                              # just one sentence!
        $self->{SID}++;
        $self->{INFO}->{'size'}++;
        push( @ids, $self->{SID} );
        $str = $self->_sentence( $data, $self->{SID}, $attr );
    }
    return $str . "\n";
}


=head2 C<markup_to_string>

Empty in this class, but may be overridden.

=cut

# do nothing (no extra markup possible in Text format)

sub markup_to_string { return ''; }

# # old version: add empty lines for page breaks
# # ---> but this is not good for Moses and aligned data!

# sub markup_to_string{
#     my $self=shift;
#     my $markup = shift || [];

#     my $string = '';
#     foreach my $e (@{$markup}){
#         if (ref($e) eq 'ARRAY'){    # it's a tag (and not text)
#             $string .= "\n" if ($$e[0] eq 'p');
#         }
#     }
#     return $string;
# }


=head2 C<_sentence_start>

=cut

sub _sentence_start { }


=head2 C<_sentence_end>

=cut

sub _sentence_end { }


=head2 C<_encode>

=cut

sub _encode {
    my ( $self, $string ) = @_;
    $string =~ s/\n/ /gs;       # keep everything on one line
    $string =~ s/\|/_/gs;       # this is to avoid Moses to crash
    $string =~ s/\s\s+/ /gs;    # only one space
    $string =~ s/^\s+//s;       # no spaces at beginning
    $string =~ s/\s+$//gs;      # no spaces at the end
    return $string;
}


=head2 C<_sentence>

=cut

# sub _encode { return $_[1]; }

sub _sentence {
    my ( $self, $data, $id, $attr ) = @_;
    if ( ref($data) eq 'ARRAY' ) {    # this is an array of tokens
        return $self->_tokenized($data);
    }
    elsif ( ref($data) eq 'HASH' ) {    # this is a tree
        return $self->_tree($data);
    }
    my $str = $self->_sentence_start($id, $attr);
    $str .= $self->_encode($data);
    $str .= $self->_sentence_end($id);
    return $str;
}


=head2 C<_tokenized>

=cut

sub _tokenized {
    my ( $self, $data, $id ) = @_;

    my $str    = $self->_sentence_start($id);
    my @tokens = ();
    foreach my $token ( @{$data} ) {
        if ( ref($token) eq 'HASH' ) {
            push( @tokens, $self->_token($token) );
        }
        else {
            push( @tokens, $self->_encode($token) );
        }
    }
    $str .= join( ' ', @tokens );
    $str .= $self->_sentence_end($id);
    return $str;
}


=head2 C<_token>

=cut

# print token prints a token with various attributes
# attribute 'word' = actual token

sub _token {
    my ( $self, $token ) = @_;

    my $str = ' ';

    my @factors = ();
    foreach my $k ( sort keys %{$token} ) {
        push( @factors, $self->_encode( $$token{$k} ) );
    }
    my $del = $self->{-delimiter} || '|';
    $str .= join( '|', @factors );
    return $str;
}


=head2 C<_tree>

=cut

# not implemented yet ....

sub _tree {
    my ( $self, $data, $id ) = @_;
    my $str = $self->_sentence_start($id);
    $str .= $self->_sentence_end($id);
}


=head2 C<_header>

=cut

sub _header { }


=head2 C<_tail>

=cut

sub _tail { }


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
