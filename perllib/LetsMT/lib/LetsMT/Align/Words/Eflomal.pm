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


# eflomal
our $EFLOMAL = $ENV{LETSMTROOT}.'/share/eflomal/align.py';
# our $EFLOMAL = `which eflomal.py` || undef;
chomp($EFLOMAL);


## atools for symmetrisation
our $ATOOLS = `which atools` || undef;
chomp($ATOOLS);


## priors of eflomal
our $EFLOMAL_MODEL_DIR = $LetsMT::EFLOMAL_MODEL_DIR || 
    '/usr/local/share/eflomal/priors';


=head1 CONSTRUCTOR

 $aligner = new LetsMT::Align::Words::Eflomal

=cut

sub new {
    my $class = shift;
    my %self  = @_;

    $self{eflomal} = $EFLOMAL unless (defined $self{eflomal});
    $self{atools}  = $ATOOLS  unless (defined $self{atools});

    $self{prefix}     = '4' unless (exists $self{prefix});
    $self{src_prefix} = $self{prefix} unless (exists $self{src_prefix});
    $self{trg_prefix} = $self{prefix} unless (exists $self{trg_prefix});

    $self{symmetrization} = 'grow-diag-final-and' unless ($self{symmetrization});

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

    my ($source_resource, $target_resource) = $self->_prepare($SentAlgResource,$WordAlgIDsResource);
    return undef unless (ref($source_resource));
    return undef unless (ref($target_resource));

    my $srcfile = $source_resource->local_path();
    my $trgfile = $target_resource->local_path();
    my $fwdfile = $ForwardWordAlgResource->local_path();
    my $revfile = $ReverseWordAlgResource->local_path();

    my $srclang = $source_resource->language();
    my $trglang = $target_resource->language();
    my $priors  = $EFLOMAL_MODEL_DIR.'/'.$srclang.'-'.$trglang.'.priors';
    unless (-e $priors){
	if (-e $priors.'.gz'){
	    my ( $fh, $tmpfile ) = tempfile(
		'eflomal_XXXXXXXX',
		DIR    => $ENV{UPLOADDIR},
		UNLINK => 1
		);
	    close $fh;
	    if (&pipe_in_out_cmd($priors.'.gz',$tmpfile,'gzip','-cd')){
		$priors = $tmpfile;
	    }
	    else{
		$priors = undef;
	    }
	}
	else{
	    $priors = undef;
	}
    }

    ## make eflomal arguments
    my @para = (
	'-s', $srcfile,
        '-t', $trgfile,
	'-f', $fwdfile,
        '-r', $revfile,
	'--source-prefix', $self->{src_prefix},
	'--target-prefix', $self->{trg_prefix},
	'--overwrite'
	);

    ## add parameter about priors if they exist
    if ($priors){
	push (@para,'--priors',$priors);
    }

    ## run eflomal
    my ( $success, $ret, $out, $err ) = &run_cmd( $self->{eflomal}, @para );
    return undef unless ($success);

    ## symmetrisation
    my $ForwardWordAlgResource = $WordAlgResource->graft_suffix('.forward');
    if (&pipe_out_cmd(
	     $WordAlgResource->local_path(),
	     $self->{atools},
	     '-c', $self->{symmetrization},
	     '-i', $fwdfile,
	     '-j', $revfile) ){

	## return all new resource (fwd,rev,symm,xces)
	return ($WordAlgResource, $WordAlgIDsResource, 
		$ForwardWordAlgResource, $ReverseWordAlgResource);
    }
    return undef;
}



## convert to temporary Moses format for running eflomal
## NOTE! don't forget tokenization! (if not tokenized already)
## write also a new XCES align file to store sent-alignments of wordaligned sentence pairs

sub _prepare{
    my $self=shift;
    my ($algres, $idres) = @_;

    ## read and write handlers
    my ($reader, $xces_writer, $moses_writer);

    ## create a reader with tokenized data as default (UD-parsed as default)
    unless ( $reader = new LetsMT::Export::Reader( $algres, 'xces', 
						   type => 'ud', 
						   fallback_type => 'tok' ) ) {
        get_logger(__PACKAGE__)->error("cannot read $algres");
    }

    ## create XCES write for storing aligned sentence IDs
    ## --> this is necessary because some alignments may be skipped
    ##     (empty alignments etc)
    unless ( $xces_writer = new LetsMT::Export::Writer( $idres, 'xces' ) ) {
        get_logger(__PACKAGE__)->error("cannot write to $idres");
    }

    ## temporary plain text files
    my $tmpdir = tempdir(
    	'wordalign_XXXXXXXX',
    	DIR     => $ENV{UPLOADDIR},
    	CLEANUP => 1
        );

    my $mosesres = $idres->clone()->strip_suffix();
    $mosesres->local_path($tmpdir);

    ## create Moses file format writer
    unless ( $moses_writer = new LetsMT::Export::Writer( $mosesres, 'moses' ) ) {
        get_logger(__PACKAGE__)->error("cannot write to $mosesres");
    }

    ## open all streams
    $reader->open($algres);
    $moses_writer->open($mosesres);
    $xces_writer->open($idres);

    ## read input and write to XCES and Moses resources
    my $count = 0;
    while ( my $data = $reader->read() ) {
	if ($moses_writer->write( $data )){
	    $xces_writer->write( $data );
	    $count++;
	}
    }

    $reader->close();
    $moses_writer->close();
    $xces_writer->close();

    ## need non-empty files
    return undef unless ($count);

    ## return the temporary aligned text file resources
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
