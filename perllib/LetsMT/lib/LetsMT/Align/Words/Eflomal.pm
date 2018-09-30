package LetsMT::Align::Words::Eflomal;

=head1 NAME

LetsMT::Align::Words::Eflomal - word alignment with eflomal

=head1 DESCRIPTION

=cut

use strict;

use LetsMT::Export::Reader;
use LetsMT::Export::Writer;
use LetsMT::Tools;
use LetsMT::WebService;
use LetsMT::DataProcessing::Tokenizer;


use File::Temp qw/tempfile tempdir/;
use File::Basename;
use File::Copy;
use File::Path;


our $EFLOMAL = `which eflomal.py` || undef;
chomp($EFLOMAL);

=head1 CONSTRUCTOR

 $aligner = new LetsMT::Align::Words::Eflomal

=cut

sub new {
    my $class = shift;
    my %self  = @_;

    $self{eflomal} = $self{eflomal} || $EFLOMAL;
    $self{tokenizer} = {};

    return bless \%self, $class;
}


## run eflomal and store word alignment

sub wordalign{
    my $self = shift;
    my ( $SentAlgResource, $WordAlgResource ) = @_;

    unless ($WordAlgResource){
	$WordAlgResource = $SentAlgResource->strip_suffix();
	$WordAlgResource->base_path('wordalign');
    }

    my $ForwardWordAlgResource = $WordAlgResource->graft_suffix('.forward');
    my $ReverseWordAlgResource = $WordAlgResource->graft_suffix('.reverse');
    my $WordAlgIDsResource     = $WordAlgResource->graft_suffix('.xml');


#    my $outdir = dirname($ForwardWordAlgResource->local_path());
#    &run_cmd( 'mkdir', '-p', $outdir );

    my ($source_resource, $target_resource) = $self->_prepare($SentAlgResource,$WordAlgIDsResource);
    my $srcfile = $source_resource->local_path();
    my $trgfile = $target_resource->local_path();
    my $fwdfile = $ForwardWordAlgResource->local_path();
    my $revfile = $ReverseWordAlgResource->local_path();

    my ( $success, $ret, $out, $err ) = &run_cmd(
        $self->{eflomal},
        '-s', $srcfile,
        '-t', $trgfile,
	'-f', $fwdfile,
        '-r', $revfile
    );

    ## symmetrisation
    ## return all new resource (fwd,rev,symm,xces)

}



## convert to temporary Moses format for running eflomal
## NOTE! don't forget tokenization! (if not tokenized already)
## write also a new XCES align file to store sent-alignments of wordaligned sentence pairs

sub _prepare{
    my $self=shift;
    my ($algres, $idres) = @_;

    # my ( $src, $srcfile ) = tempfile(
    #     'align_XXXXXXXX',
    #     DIR    => $ENV{UPLOADDIR},
    #     UNLINK => 1
    # );
    # binmode( $src, ':encoding(utf8)' );
    # my ( $trg, $trgfile ) = tempfile(
    #     'align_XXXXXXXX',
    #     DIR    => $ENV{UPLOADDIR},
    #     UNLINK => 1
    # );
    # binmode( $trg, ':encoding(utf8)' );

    my $tmpdir = tempdir(
    	'wordalign_XXXXXXXX',
    	DIR     => $ENV{UPLOADDIR},
    	CLEANUP => 1
        );

    $algres->local_dir($tmpdir);
    $idres->local_dir($tmpdir);

    my ($reader, $xces_writer, $moses_writer);
    unless ( $reader = new LetsMT::Export::Reader( $algres, 'xces' ) ) {
        get_logger(__PACKAGE__)->error("cannot read $algres");
    }
    unless ( $xces_writer = new LetsMT::Export::Writer( $idres, 'xces' ) ) {
        get_logger(__PACKAGE__)->error("cannot write to $idres");
    }

    my $mosesres = $idres->clone()->strip_suffix();
    $mosesres->local_path($tmpdir);


    unless ( $moses_writer = new LetsMT::Export::Writer( $mosesres, 'moses' ) ) {
        get_logger(__PACKAGE__)->error("cannot write to $mosesres");
    }

    $reader->open($algres);
    $moses_writer->open($mosesres);
    $xces_writer->open($idres);

    while ( my $data = $reader->read() ) {
	if ($moses_writer->write( $data )){
	    $xces_writer->write( $data );
	}
    }

    $reader->close();
    $moses_writer->close();
    $xces_writer->close();

    return ($moses_writer->get_source_resource,$moses_writer->get_target_resource);

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
