package LetsMT::Export::Writer::XCES;

=head1 NAME

LetsMT::Export::Writer::XCES - writer for C<XCES> data

=head1 DESCRIPTION

L<XCES|http://www.xces.org/>:
the XML Corpus Encoding Standard
- an XML-based standard to codify text corpora.

=cut

use strict;
use parent 'LetsMT::Export::Writer';  # inherit get_resources method

use LetsMT::Resource;
use LetsMT::Tools qw/cacheopen cacheclose append/;

use File::Path;
use File::Basename;

# file cache takes care of possible file open limits!
# no strict 'refs';
# use FileCache maxopen => 100;


=head1 CONSTRUCTOR

Enforces 'utf8' encoding.

=cut

sub new {
    my $class = shift;
    my %self = ( -encoding => 'utf8', maxopen => 100, @_ );

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

    $self->{SID} = 0;
    &File::Path::make_path( dirname( $resource->local_path ) );

#    $self->{FH} = &LetsMT::Tools::open_out_file( $resource->local_path,
#        $self->{-encoding} );

    &cacheopen($resource->local_path, $self->{-encoding});
    $self->{FH} = &append($resource->local_path,&_header);

    return $self->{FH};
}


=head2 C<close>

=cut

sub close {
    my $self = shift;
    my $fh   = $self->{FH};
    if ($fh) {
        $self->close_document_pair if ( $self->{LINKGRP} );
	&append($fh,&_tail);
	return &cacheclose($fh);
#        return $fh->close;
    }
    return undef;
}


=head2 C<open_document_pair>

=cut

sub open_document_pair {
    my $self = shift;
    my $fh   = $self->{FH};
    $self->close_document_pair if ( $self->{LINKGRP} );
    &append($fh,&_open_linkGrp(@_));
    $self->{LINKGRP} = 1;
}


=head2 C<close_document_pair>

=cut

sub close_document_pair {
    my $self = shift;
    my $fh   = $self->{FH};
    &append($fh,&_close_linkGrp()) if ( $self->{LINKGRP} );
    delete $self->{LINKGRP};
}


=head2 C<write>

=cut

sub write {
    my $self = shift;
    my ( $SrcIDs, $TrgIDs, %para ) = @_;

    my $fh = $self->{FH};

    my $paraStr = '';
    foreach ( keys %para ) {
        $paraStr .= ' ' . $_ . '="';
        $paraStr .= &LetsMT::Tools::xmlify_with_quotes( $para{$_} );
        $paraStr .= '"';
    }

    $self->{LINKID}++;
    &append($fh,'<link id="',
	    $self->{LINKID},
	    '" xtargets="',
	    join( ' ', @{$SrcIDs} ),
	    ';',
	    join( ' ', @{$TrgIDs} ),
	    '"',
	    $paraStr,
	    ' />', "\n");
}


=head2 C<_header>

=cut

sub _header {
    return '<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE cesAlign PUBLIC "-//CES//DTD XML cesAlign//EN" "">
<cesAlign version="1.0">
';
}


=head2 C<_tail>

=cut

sub _tail {
    return "</cesAlign>\n";
}


=head2 C<_open_linkGrp>

=cut

sub _open_linkGrp {
    my ($fromDoc, $toDoc) = @_;
    my $str = '<linkGrp targType="s"';

    # add revision attributes if necessary
    $fromDoc =~ s/@([0-9]+)$// and $str .= ' fromDocRev="'.$1.'"';
    $toDoc   =~ s/@([0-9]+)$// and $str .= ' toDocRev="'.$1.'"';
    $fromDoc =~ s/@([0-9]*)$//;
    $toDoc   =~ s/@([0-9]*)$//;

    return  $str . ' fromDoc="' . $fromDoc . '" toDoc="' . $toDoc . "\">\n";
}


=head2 C<_close_linkGrp>

=cut

sub _close_linkGrp {
    return "</linkGrp>\n";
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
