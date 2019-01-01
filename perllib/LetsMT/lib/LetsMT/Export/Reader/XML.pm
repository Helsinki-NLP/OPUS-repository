package LetsMT::Export::Reader::XML;

=head1 NAME

LetsMT::Export::Reader::XML

=cut

use strict;

use XML::Parser;
use Log::Log4perl qw(get_logger :levels);

use LetsMT::Resource;
use LetsMT::WebService;
use LetsMT::Tools;
use LetsMT::Tools::XML qw/:all/;
use LetsMT::Import;

=head1 CONSTRUCTOR

=cut

sub new {
    my $class = shift;
    my %self = ( SID => 0, -encoding => 'utf8', @_ );

    $self{normalizer} = $LetsMT::Import::DEFAULT_NORMALIZER  unless ( defined $self{normalizer} );
    $self{tokenizer}  = $LetsMT::Import::DEFAULT_TOKENIZER   unless ( defined $self{tokenizer} );

    $self{PARSEROBJECT} = new XML::Parser(
        Handlers => {
            Start => \&__XmlTagStart,
            End   => \&__XmlTagEnd,
            Char  => \&__XmlChar
        }
    );

    bless \%self, $class;
    return \%self;
}


=head1 METHODS

=head2 C<open>

 $reader->open ($resource, %params)

=cut

sub open {
    my $self = shift;
    my $resource = shift || $self->{resource};

    # store language of the resource to be opened
    $self->{language} = $resource->language() unless $self->{language};

    $self->{XMLPARSER} = $self->{PARSEROBJECT}->parse_start;

    # Get requested resource if necessary

    if ( ( !-e $resource->local_path ) || $self->{-always_fetch} ) {
        unless ( &LetsMT::WebService::get_resource($resource) ) {
            get_logger(__PACKAGE__)->error("Unable to fetch '$resource'");
            return 0;
        }
    }

    $self->{SID} = 0;
    $self->{FH}  = &LetsMT::Tools::open_in_file( $resource->local_path,
        $self->{-encoding} );

    return $self->{FH};
}


=head2 C<close>

=cut

sub close {
    my $self = shift;
    if ( ref( $self->{FH} ) ) {
        return $self->{FH}->close;
    }
    return undef;
}


=head2 C<read>

=cut

sub read {
    my $self   = shift;
    my ($before,$after,$sattr) = @_;

    my $data = {};
    my $fh   = $self->{FH};

    # initialize ....
    $self->{XMLPARSER}->{BEFORE} = [] if ( ref($before) eq 'HASH' );
    delete $self->{XMLPARSER}->{CLOSED_S};

    my $OldDel = $/;
    $/ = '>';
    while (<$fh>) {
        clean_xml_no_copy($_);
        eval { $self->{XMLPARSER}->parse_more($_); };
        warn $@ if ($@);
        last if ( exists $self->{XMLPARSER}->{CLOSED_S} );
    }
    $/ = $OldDel;

    if ( exists $self->{XMLPARSER}->{CLOSED_S} ) {
        $self->{SID}++;
        my $id
            = $self->{XMLPARSER}->{CLOSED_S}
            ? $self->{XMLPARSER}->{CLOSED_S}
            : $self->{SID};

	$self->{normalizer}->normalize_no_copy( $self->{XMLPARSER}->{SENT} );
        $data->{ $self->{language} }->{$id} = 
	    $self->{tokenizer}->tokenize( $self->{XMLPARSER}->{SENT} );

        # data from before the sentences
        if ( ref($before) eq 'HASH' ) {
            $before->{ $self->{language} } = $self->{XMLPARSER}->{BEFORE};
        }
        if ( ref($sattr) eq 'HASH' ) {
	    if ( ref($self->{XMLPARSER}->{SATTR}) eq 'HASH' ){
		%{$$sattr{ $self->{language} }{ $id }} = %{$self->{XMLPARSER}->{SATTR}};
	    }
	}
        return $data;
    }

    # reached end of file!
    $self->close;
    return undef;
}


=head1 INTERNAL CLASS METHODS - XML parser call-back functions

XML parser handlers for corpus parser (separate for source and target).

=head2 C<__XmlTagStart>

 LetsMT::Export::Reader::XML::__XmlTagStart ($p, $e, %a)

=cut

sub __XmlTagStart {
    my ( $p, $e, %a ) = @_;

    if ( $e eq 's' ) {
        $p->{OPEN_S} = $a{id};
        delete $p->{CLOSED_S};
        $p->{SENT} = '';
	%{$p->{SATTR}} = %a;
        return 1;
    }
    elsif ( ref( $p->{BEFORE} ) eq 'ARRAY' ) {
        if ( $p->{INSIDE_BODY} ) {
            push( @{ $p->{BEFORE} }, [ $e, \%a ] );
        }
        elsif ( $e=~/^(body|text|letsmt)$/) {
            $p->{INSIDE_BODY} = 1;
        }
    }
}


=head2 C<__XmlChar>

 LetsMT::Export::Reader::XML::__XmlChar ($p, $e)

=cut

sub __XmlChar {
    my ( $p, $c ) = @_;
    if ( exists $p->{OPEN_S} ) {
        $p->{SENT} .= $c;
    }
}


=head2 C<__XmlTagEnd>

 LetsMT::Export::Reader::XML::__XmlTagEnd ($p, $e, %a)

=cut

sub __XmlTagEnd {
    my ( $p, $e, %a ) = @_;

    if ( $e eq 's' ) {
	$p->{SENT} =~s/^\s*//s;
	$p->{SENT} =~s/\s*$//s;
        $p->{CLOSED_S} = $p->{OPEN_S};
        delete $p->{OPEN_S};
    }
    elsif ( ref( $p->{BEFORE} ) eq 'ARRAY' ) {
        if ( $p->{INSIDE_BODY} ) {
            push( @{ $p->{BEFORE} }, [$e] );
        }
        elsif ( $e eq 'body' ) {
            delete $p->{INSIDE_BODY};
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
