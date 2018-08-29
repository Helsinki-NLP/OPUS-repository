package LetsMT::Export::Reader::Converter;

=head1 NAME

LetsMT::Export::Reader::Converter - read documents after converting to XML

=head1 DESCRIPTION

A general reader module that first converts to XML
(using modules from the Import class)
and then reads the converted file.

=cut

use strict;

use Log::Log4perl qw(get_logger :levels);

use LetsMT::Resource;
use LetsMT::WebService;
use LetsMT::Tools;

use LetsMT::Import::PDF;
use LetsMT::Import::Tika;

use LetsMT::Export::Reader::XML;
use LetsMT::Import;


=head1 CONSTRUCTOR

 $reader = new LetsMT::Export::Reader::Converter (format => $format)

Supported formats:

=over

=item doc

=item pdf

=back

=cut

sub new {
    my $class = shift;
    my %self  = @_;

#    if ( $self{format} =~ /doc/i ) {
#        $self{CONVERTER} = new LetsMT::Import::DOC(%self);
#    }
    if ( $self{format} =~ /pdf/i ) {
        $self{CONVERTER} = new LetsMT::Import::PDF(%self);
    }
    # default converter = Tika (can detect document formats!)
    else {
#        $self{CONVERTER} = new LetsMT::Import::Tika(%self);
        $self{CONVERTER} = new LetsMT::Import::ApacheTika(%self);
    }
    $self{READER} = new LetsMT::Export::Reader::XML(%self);

    bless \%self, $class;
    return \%self;
}


=head1 METHODS

=head2 C<open>

=cut

sub open {
    my $self = shift;
    my $resource = shift || $self->{resource};

    my $converted
        = $self->{CONVERTER}->convert( $resource, new LetsMT::Import );
    if ( @{$converted} ) {
        return $self->{READER}->open( $converted->[0]->{resource} );
    }
    return undef;
}


=head2 C<close>

=cut

sub close {
    my $self = shift;
    return $self->{READER}->close;
}


=head2 C<read>

=cut

sub read {
    my $self = shift;
    return $self->{READER}->read(@_);
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
