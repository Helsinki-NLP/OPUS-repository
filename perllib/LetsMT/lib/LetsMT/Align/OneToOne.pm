package LetsMT::Align::OneToOne;

=head1 NAME

LetsMT::Align::OneToOne - Sentence-align one to one

=head1 DESCRIPTION

=cut

use strict;
use parent 'LetsMT::Align';

use Log::Log4perl qw(get_logger :levels);

use LetsMT::Export::Reader;
use LetsMT::Export::Writer;
use LetsMT::Export::Writer::XCES;
use LetsMT::WebService;


=head1 CONSTRUCTOR

 $aligner = new LetsMT::Align (method => 'one-to-one', %params)

=cut

sub new {
    my $class = shift;
    my %self  = @_;

    ## save given arguments to save them later in metadata
    %{ $self{args} } = @_;

    return bless \%self, $class;
}


=head1 METHODS

=head2 C<align>

=cut

sub align {
    my $self = shift;
    my ( $SrcResource, $TrgResource, $AlgResource ) = @_;

    # swap if needed (language IDs should be sorted)
    if ( $SrcResource->language() gt $TrgResource->language() ) {
        ( $SrcResource, $TrgResource ) = ( $TrgResource, $SrcResource );
    }

    unless ( ref($AlgResource) ) {
        $AlgResource = &LetsMT::Align::make_align_resource( $SrcResource,
            $TrgResource );
    }

    my ( $SrcReader, $TrgReader );
    unless ( $SrcReader = new LetsMT::Export::Reader( $SrcResource, 'xml' ) )
    {
        get_logger(__PACKAGE__)->error("cannot read $SrcResource");
    }
    unless ( $TrgReader = new LetsMT::Export::Reader( $TrgResource, 'xml' ) )
    {
        get_logger(__PACKAGE__)->error("cannot read $TrgResource");
    }

    $SrcReader->open($SrcResource);
    $TrgReader->open($TrgResource);

    # my $writer = new LetsMT::Export::Writer::XCES();
    # $writer->open($AlgResource);
    # $writer->open_document_pair( $AlgResource->fromDoc, $AlgResource->toDoc );

    $self->{SIZE}    = 0;
    my @links        = ();
    my %DetectedLang = ();

    while ( my $data = $SrcReader->read(undef, undef, \%DetectedLang) ) {
        my @sids = ();
        foreach my $l ( keys %{$data} ) {
            push( @sids, keys %{ $$data{$l} } );
        }
        my @tids = ();
        if ( my $data = $TrgReader->read(undef, undef, \%DetectedLang) ) {
            foreach my $l ( keys %{$data} ) {
                push( @tids, keys %{ $$data{$l} } );
            }
        }
	my $idx = @links;
	@{$links[$idx]{src}} = @sids;
	@{$links[$idx]{trg}} = @tids;

        # $writer->write( \@sids, \@tids );
        # $self->{NrLinks}++;
        # my $nrSrc = scalar @sids;
        # my $nrTrg = scalar @tids;
        # $self->{NrSrcSents} += $nrSrc;
        # $self->{NrTrgSents} += $nrTrg;
        # $self->{LinkTypes}->{"$nrSrc:$nrTrg"}++;
    }


    # remaining target sentences will be aligned to nothing .....
    my @tids = ();
    while ( my $data = $TrgReader->read(undef, undef, \%DetectedLang) ) {
        foreach my $l ( keys %{$data} ) {
            push( @tids, keys %{ $$data{$l} } );
        }
	my $idx = @links;
	@{$links[$idx]{src}} = ();
	@{$links[$idx]{trg}} = @tids;

        # $writer->write( [], \@tids );
        # $self->{NrLinks}++;
        # my $nrTrg = scalar @tids;
        # $self->{NrTrgSents} += $nrTrg;
        # $self->{LinkTypes}->{"0:$nrTrg"}++;
    }

    $SrcReader->close();
    $TrgReader->close();
    # $writer->close();

    $self->write_links($AlgResource, \@links, \%DetectedLang);

    return $AlgResource;
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
