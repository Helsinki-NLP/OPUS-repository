package LetsMT::Export::Reader::XCES;

=head1 NAME

LetsMT::Export::Reader::XCES - reader for C<XCES> data

=head1 DESCRIPTION

L<XCES|http://www.xces.org/>:
the XML Corpus Encoding Standard
- an XML-based standard to codify text corpora.

=cut

use strict;

use Log::Log4perl qw(get_logger :levels);

use XML::Parser;
use FileHandle;
use File::Basename;

use LetsMT::Resource;
use LetsMT::Tools;
use LetsMT::Tools::XML qw/:all/;
use LetsMT::Export::Reader::XML;
use LetsMT::Corpus;


=head1 CONSTRUCTOR

=cut

sub new {
    my $class = shift;
    my %self = ( LID => 0, -encoding => 'utf8', @_ );

    $self{type}     = 'xml'       unless (defined $self{type});
    $self{src_type} = $self{type} unless (defined $self{src_type});
    $self{trg_type} = $self{type} unless (defined $self{trg_type});
    $self{fallback_type} = 'xml'  unless (defined $self{fallback_type});

    # XML Parser object for parsing sentence alignments

    $self{BitextParserObject} = new XML::Parser(
        Handlers => {
            Start => \&__AlignTagStart,
            End   => \&__AlignTagEnd
        }
    );

    # XML Reader objects for source and target language

    $self{SRC} = new LetsMT::Export::Reader::XML;
    $self{TRG} = new LetsMT::Export::Reader::XML;

    bless \%self, $class;
    return \%self;
}


=head1 METHODS

=head2 C<open>

 $reader->open ($resource, %params)

=cut

sub open {
    my $self     = shift;
    my $resource = shift || $self->{resource};
    my %para     = @_;

    # set additional parameters
    foreach ( keys %para ) { $self->{$_} = $para{$_}; }

    $self->{AlignResource} = $resource;
    $self->{BitextParser}  = $self->{BitextParserObject}->parse_start;

    # get requested resource if necessary
    if ( ( !-e $resource->local_path ) || $self->{-always_fetch} ) {
        unless ( &LetsMT::WebService::get_resource($resource) ) {
            get_logger(__PACKAGE__)->error("Unable to fetch '$resource'");
            return 0;
        }
    }

    $self->{LID} = 0;
    $self->{FH}  = &LetsMT::Tools::open_in_file( $resource->local_path,
        $self->{-encoding} );

    # link type parameter:
    #   set number of required source/target sentences!
    if ( defined $self->{-link_type} ) {
        ( $self->{REQUIRE_SRC}, $self->{REQUIRE_TRG} )
            = split( ':', $self->{-link_type} );
    }

    return $self->{FH};
}


=head2 C<close>

=cut

sub close {
    my $self = shift;
    return $self->{FH}->close;
}


=head2 C<read>

=cut

sub read {
    my $self = shift;
#    my $data = shift || {};
    my $data = {};

    my $fh = $self->{FH};

    my $OldDel = $/;
    $/ = '>';

    while (<$fh>) {
        clean_xml_no_copy($_);
        eval { $self->{BitextParser}->parse_more($_); };
        die $@ if ($@);

        # fetch & open a new bitext!
        if ( $self->{BitextParser}->{OPEN} ) {
            $self->__OpenCorpora(
                $self->{BitextParser}->{FROMDOC},
                $self->{BitextParser}->{TODOC}
            );
            delete $self->{BitextParser}->{OPEN};
        }

        # close current bitext
        elsif ( $self->{BitextParser}->{CLOSE} ) {
            $self->__CloseCorpora();
            delete $self->{BitextParser}->{CLOSE};
        }

        # retrieve sentences for current alignment pair
        # from source and target document
        # and return data
        elsif ( defined $self->{BitextParser}->{SRCSENT} ) {
            if ( defined $self->{BitextParser}->{TRGSENT} ) {
                $/ = $OldDel;

                # what kind of structure are we using here?
                # data->{srclang}= array of sentence (structures?)
                my @srcids = split( /\s+/, $self->{BitextParser}->{SRCSENT} );
                my @trgids = split( /\s+/, $self->{BitextParser}->{TRGSENT} );

                delete $self->{BitextParser}->{SRCSENT};
                delete $self->{BitextParser}->{TRGSENT};

                # require a specific number of sentences on source or target
                # (--> can restrict link types, e.g., to 1:1 links only)
                next
                    if ( defined( $self->{REQUIRE_SRC} )
                    && ( $self->{REQUIRE_SRC} != $#srcids + 1 ) );
                next
                    if ( defined( $self->{REQUIRE_TRG} )
                    && ( $self->{REQUIRE_TRG} != $#srcids + 1 ) );

                # try to get the sentences from the monolingual corpora
                # if it fails: re-open the files (because we might have
                # ended up at the end of the corpus while looking for the IDs)

                my %OldData  = %{$data};
                my $srcidstr = join( ':', @srcids );
                my $trgidstr = join( ':', @trgids );

                # print "look for $srcidstr .. $trgidstr\n";

                if ( !$self->GetSentencesFromCache( $data, \@srcids, \@trgids ) ) {
                # if ( !$self->GetSentences( $data, \@srcids, \@trgids ) ) {
                    warn
                        "Warning! Cannot find source sentences $srcidstr and/or target sentences $trgidstr!\n";
                    %{$data} = %OldData;
                    $self->__CloseCorpora;
                    $self->__OpenCorpora(
                        $self->{BitextParser}->{FROMDOC},
                        $self->{BitextParser}->{TODOC},
                    );
                    next;
                }
                return $data;
            }
        }
    }
    $/ = $OldDel;
    return undef;    # end-of-file
}


=head2 C<GetSentences>

 $reader->GetSentences ($data, $source_IDs, $target_IDs)

=cut

sub GetSentences {
    my $self = shift;
    my ( $data, $srcids, $trgids ) = @_;
    my $srclang = $self->{SRCLANG};
    my $trglang = $self->{TRGLANG};

    while ( @{$srcids} ) {
        my $new = $self->{SRC}->read() || return 0;
        my ($lang) = keys %{$new};
        if ( defined $$new{$lang}{ $$srcids[0] } ) {
            my $id = shift( @{$srcids} );
            $$data{$srclang}{$id} = $$new{$lang}{$id};
        }
        # else{
        #     die "found src ", join(':',keys %new), " but look for $$srcids[0]\n";
        # }
    }
    while ( @{$trgids} ) {
        my %new    = ();
        my $new    = $self->{TRG}->read() || return 0;
        my ($lang) = keys %{$new};
        if ( defined $$new{$lang}{ $$trgids[0] } ) {
            my $id = shift( @{$trgids} );
            $$data{$trglang}{$id} = $$new{$lang}{$id};
        }
        # else{
        #     die "found trg ", join(':',keys %new), " but look for $$trgids[0]\n";
        # }
    }
    return 1;
}




## get sentences from a cache
## where we have all sentences of the document stored

sub GetSentencesFromCache {
    my $self = shift;
    my ( $data, $srcids, $trgids ) = @_;
    my $srclang = $self->{SRCLANG};
    my $trglang = $self->{TRGLANG};

    unless (ref($self->{SRC_CACHE}) eq 'HASH'){
	$self->{SRC_CACHE} = ();
	$self->GetAllSentences($self->{SRC},$self->{SRC_CACHE});
    }
    unless (ref($self->{TRG_CACHE}) eq 'HASH'){
	$self->{TRG_CACHE} = ();
	$self->GetAllSentences($self->{TRG},$self->{TRG_CACHE});
    }

    foreach my $id ( @{$srcids} ) {
	if (exists $self->{SRC_CACHE}->{$id}){
	    $$data{$srclang}{$id} = $self->{SRC_CACHE}->{$id};
	}
	else{
	    warn "cannot find source sentence $id";
	}
    }
    foreach my $id ( @{$trgids} ) {
	if (exists $self->{TRG_CACHE}->{$id}){
	    $$data{$trglang}{$id} = $self->{TRG_CACHE}->{$id};
	}
	else{
	    warn "cannot find target sentence $id";
	}
    }

    ## TODO: always return 1?
    return 1;
}


sub GetAllSentences {
    my $self = shift;
    my ( $reader, $cache ) = @_;

    my $count=0;
    while (my $new = $reader->read()){
        my ($lang) = keys %{$new};
        foreach my $id ( keys %{$$new{$lang}} ) {
	    $$cache{$id} = $$new{$lang}{$id};
	    $count++;
        }
    }
    return $count;
}





# sub ParseAllSentences{
#     my ($handle,$fh,$container,$wordcounter)=@_;

#     while (<$fh>){
#         eval { $handle->parse_more($_); };
#         if ($@){
#             warn $@;
#             print STDERR $_;
#         }
#         if (exists $handle->{CLOSEDSID}){
#             $$container{$handle->{CLOSEDSID}} = $handle->{OUTSTR};
#             $$wordcounter{$handle->{CLOSEDSID}} = $handle->{NRWORDS};
#             $handle->{OUTSTR} = '';
#             $handle->{NRWORDS} = 0;
#             delete $handle->{CLOSEDSID};
# 	}
#     }
#     print '';
# }



=head1 INTERNAL METHODS

=head2 C<__OpenCorpora>

 $reader->__OpenCorpora ($fromDoc, $toDoc)

Make new LetsMT-CorpusFile objects and open them.

=cut

sub __OpenCorpora {
    my $self = shift;
    my ( $fromDoc, $toDoc ) = @_;

    # fromDoc (source language)

    my $FromResource = $self->{AlignResource}->clone;
    $FromResource->path( $self->{src_type} . '/' . $fromDoc );
    unless (&LetsMT::Corpus::resource_exists($FromResource)){
	$FromResource->path( $self->{fallback_type} . '/' . $fromDoc );
    }

    if ( ( !-e $FromResource->local_path ) || $self->{-always_fetch} ) {
        unless ( &LetsMT::WebService::get_resource($FromResource) ) {
            get_logger(__PACKAGE__)->error("Unable to fetch '$FromResource'");
            return 0;
        }
    }

    $self->{SRC}->open($FromResource);
    $self->{SRCLANG} = $self->{-srclang};
    if ( !defined $self->{SRCLANG} ) {
        $self->{SRCLANG} = $FromResource->language() || 'source';
    }

    # toDoc (target language)

    my $ToResource = $self->{AlignResource}->clone;
    $ToResource->path( $self->{trg_type} . '/' . $toDoc );
    unless (&LetsMT::Corpus::resource_exists($ToResource)){
	$ToResource->path( $self->{fallback_type} . '/' . $toDoc );
    }

    if ( ( !-e $ToResource->local_path ) || $self->{-always_fetch} ) {
        unless ( &LetsMT::WebService::get_resource($ToResource) ) {
            get_logger(__PACKAGE__)->error("Unable to fetch '$ToResource'");
            return 0;
        }
    }

    $self->{TRG}->open($ToResource);
    $self->{TRGLANG} = $self->{-trglang};
    if ( !defined $self->{TRGLANG} ) {
        $self->{TRGLANG} = $ToResource->language() || 'target';
    }
}


=head2 C<__CloseCorpora>

=cut

sub __CloseCorpora {
    my $self = shift;
    $self->{SRC}->close();
    $self->{TRG}->close();
}


=head1 INTERNAL CLASS METHODS - XML parser call-back functions

=head2 C<__AlignTagStart>

 LetsMT::Export::Reader::XCES::__AlignTagStart ($p, $e, %a)

=cut

sub __AlignTagStart {
    my ( $p, $e, %a ) = @_;

    if ( $e eq 'linkGrp' ) {    # open a new bitext
        $p->{OPEN}    = 1;
        $p->{FROMDOC} = $a{fromDoc};
        $p->{TODOC}   = $a{toDoc};

        # add revision numbers if necessary
        $p->{FROMDOC} .= '@'.$a{fromDocRev} if (exists $a{fromDocRev});
        $p->{TODOC}   .= '@'.$a{toDocRev} if (exists $a{toDocRev});
    }

    if ( $e eq 'link' ) {
        my ( $src, $trg ) = split( /\s*\;\s*/, $a{xtargets} );
        $p->{SRCSENT} = $src;
        $p->{TRGSENT} = $trg;
    }
}


=head2 C<__AlignTagEnd>

 LetsMT::Export::Reader::XCES::__AlignTagEnd ($p, $e)

Close tags.

If a C<linkGrp>, signal that source and target corpus files are closed.

=cut

sub __AlignTagEnd {
    my ( $p, $e ) = @_;
    if ( $e eq 'linkGrp' ) {
        $p->{CLOSE} = 1;
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
