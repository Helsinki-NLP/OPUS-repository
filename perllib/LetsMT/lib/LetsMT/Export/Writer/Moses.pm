package LetsMT::Export::Writer::Moses;

=head1 NAME

LetsMT::Export::Writer::Moses - writer for I<Moses> files

=head1 DESCRIPTION

L<Moses|http://www.statmt.org/moses/>:
plain-text data used for statistical machine translation systems.

=cut

use strict;
use parent 'LetsMT::Export::Writer';  # inherit get_resources method

use LetsMT::Export::Writer::Text;
use LetsMT::Resource;
use LetsMT::Tools;


=head1 CONSTRUCTOR

=cut

sub new {
    my $class = shift;
    my %self = ( -encoding => 'utf8', @_ );

    bless \%self, $class;
    return \%self;
}


=head1 METHODS

=head2 C<open>

=cut

sub open {
    my $self     = shift;
    my $resource = shift || $self->{resource};
    my %para     = @_;

    # set additional parameters
    foreach ( keys %para ) { $self->{$_} = $para{$_}; }
    $self->{BaseResource} = $resource;

}


=head2 C<close>

=cut

sub close {
    my $self = shift;
    if ( ref( $self->{CORPUS} ) eq 'HASH' ) {
        foreach my $l ( keys %{ $self->{CORPUS} } ) {
            $self->{CORPUS}->{$l}->close();
        }
    }
}


=head2 C<get_corpus>

=cut

# keep one TextFile object per language

sub get_corpus {
    my $self = shift;
    my $lang = shift;
    return $self->{CORPUS}->{$lang} if ( defined $self->{CORPUS}->{$lang} );

    my $resource = $self->{BaseResource}->clone;
    $resource->path( $resource->path() . '.' . $lang );
    $resource->lang( $lang );

    my $encoding = $self->{-encoding} || 'utf8';

    $self->{CORPUS}->{$lang} = new LetsMT::Export::Writer::Text;
    $self->{CORPUS}->{$lang}->open( $resource, -encoding => $encoding )
        || die "cannot write to $resource!\n";

    # save resource object ...
    push( @{ $self->{RESOURCES} }, $resource );

    return $self->{CORPUS}->{$lang};
}


=head2 C<write>

=cut

sub write {
    my $self = shift;
    my $data = shift;

    # skip empty alignments!
    return 0 if ( keys %{$data} != 2 );

    # set -srclang and -trglang if they don't exist
    if ( not defined $self->{-srclang} ) {
        my @lang = sort keys %{$data};
        $self->{-srclang} = shift @lang;
    }
    if ( not defined $self->{-trglang} ) {
        my @lang = sort keys %{$data};
        $self->{-trglang} = pop @lang;
    }

    # require that both -srclang and -trglang are present
    return 0 if ( not defined $$data{ $self->{-srclang} } );
    return 0 if ( not defined $$data{ $self->{-trglang} } );

    # should do some more checks here
    # - skip empty data with empty strings
    # - max length?
    # - length ratio threshold?

    my %strings = ();
    foreach my $l ( keys %{$data} ) {
        my $corpus = $self->get_corpus($l);
        $strings{$l} = $corpus->to_string( $$data{$l} );

        # skip if the string is empty
        return 0 if ( not $strings{$l} );
        if ( $self->{-filter_max_length} ) {
            return 0
                if ( length( $strings{$l} ) > $self->{-filter_max_length} );
        }
    }

    # do something to filter data (length ratio etc ....)
    foreach my $l ( keys %{$data} ) {
        my $corpus = $self->get_corpus($l);
        $corpus->write_string( $strings{$l} );
    }
    return 1;
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