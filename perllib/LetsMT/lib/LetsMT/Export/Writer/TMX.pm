package LetsMT::Export::Writer::TMX;


=head1 NAME

LetsMT::Export::Writer::TMX

=head1 DESCRIPTION

=cut

use strict;
use parent 'LetsMT::Export::Writer::Text';

use File::Path;
use File::Basename;
use XML::Writer;

use LetsMT::Resource;
use LetsMT::Tools;


=head1 CONSTRUCTOR

=cut

sub new {
    my $class = shift;
    my %self = @_ ;

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

    # set additional parameters (but why?)
    foreach ( keys %para ) { $self->{$_} = $para{$_}; }

    my $outfile = $resource->local_path;
    &File::Path::make_path( dirname( $outfile ) );
    open $self->{FH}, '>',$outfile || return 0;

    $self->{WRITER} = new XML::Writer( OUTPUT      => $self->{FH},
				       DATA_MODE   => 1, 
				       DATA_INDENT => 2, 
				       ENCODING    => 'utf-8');

    my $time = localtime();
    $self->{WRITER}->xmlDecl();
    $self->{WRITER}->startTag('tmx', version => '1.4' );
    $self->{WRITER}->emptyTag('header', 'creationdate'        => $time,
					'srclang'             => 'unknown',
					'o-tmf'               => 'unknown',
					'segtype'             => 'sentence',
					'creationtool'        => 'OPUS',
					'creationtoolversion' => 'unknown',
					'datatype'            => 'PlainText' );
    $self->{WRITER}->startTag('body');
    return $self->{FH};
}


=head2 C<close>

=cut

sub close {
    my $self = shift;
    my $fh   = $self->{FH};
    if ($fh) {
	$self->{WRITER}->endTag('body');
	$self->{WRITER}->endTag('tmx');
	return $fh->close;
    }
    return undef;
}


=head2 C<write>

=cut

sub write {
    my $self = shift;
    my $data = shift;

    ## before and after are not used ....
    my $before = shift || {};
    my $after  = shift || {};

    my $fh = $self->{FH};
    if ( ref($data) eq 'HASH' ) {
	$self->{WRITER}->startTag('tu');
        foreach my $l ( keys %{$data} ) {
	    $self->{WRITER}->startTag('tuv', 'xml::lang' => $l);
            $self->to_string( $$data{$l} );
	    $self->{WRITER}->endTag('tuv');
	}
	$self->{WRITER}->endTag('tu');
    }
}

## TODO: can we save IDs in seg's?
sub _sentence_start {
    my ( $self, $id ) = @_;
    # $self->{WRITER}->startTag('seg', 'id' => $id);
    $self->{WRITER}->startTag('seg');
    return '';
}

sub _sentence_end {
    my ( $self, $id ) = @_;
    $self->{WRITER}->endTag('seg');
    return '';
}

sub _encode {
    my ( $self, $string ) = @_;
    $string=~s/^\s+/ /;
    $string=~s/\s+$/ /;
    $self->{WRITER}->characters( $string );
    return '';
}

## only print the actual word
sub _token {
    my ( $self, $token ) = @_;
    $self->_encode( $$token{word} );
    return '';
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
