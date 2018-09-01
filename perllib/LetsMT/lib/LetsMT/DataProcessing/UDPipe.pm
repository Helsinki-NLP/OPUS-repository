package LetsMT::DataProcessing::UDPipe;

=head1 NAME

LetsMT::DataProcessing::UDPipe

=head1 DESCRIPTION

Load and run UDPipe

=cut

use strict;
use open qw(:std :utf8);

use File::Basename;
use Ufal::UDPipe;

use LetsMT;
use LetsMT::Lang::ISO639;

our $UDPIPE_MODEL_DIR     = $LetsMT::UDPIPE_MODEL_DIR || '/usr/local/share/UDPipe';
our $UDPIPE_MODEL_VERSION = $LetsMT::UDPIPE_MODEL_VERSION || 'ud-2.0-170801';


sub new {
    my $class = shift;
    my %self  = @_;

    $self{modeldir}  = $UDPIPE_MODEL_DIR unless ($self{modeldir});
    $self{models}    = {};
    $self{tokenizer} = {};

    if ( -d $self{modeldir} ){
	my @models = glob("$self{modeldir}/*-ud-*.udpipe");
	unless ($self{version}){
	    my $modelbase = basename($models[0]);
	    if ($modelbase =~/ud-(.*).udpipe$/){
		$self{version} = $1;
	    }
	}
	foreach (@models){
	    my $modelbase = basename($_);
	    if ($modelbase=~/^(.+)\-(ud)\-(.+).udpipe$/){
		my ($lang,$version) = ($1,$3);
		$lang =~s/[\_\-]/ /g;
		my $id = iso639_NameToTwo($lang);
		if ($id=~/^..(\_..)?$/){
		    $self{models}{$id}{$version} = 
			join('/', ($self{modeldir}, $modelbase) );
		}
	    }
	}
    }

    $self{conllu}    = Ufal::UDPipe::OutputFormat::newOutputFormat("conllu");
    $self{text}      = Ufal::UDPipe::OutputFormat::newOutputFormat("horizontal");
    $self{sentence}  = Ufal::UDPipe::Sentence->new();

    bless \%self, $class;
    return \%self;
}



# load a model (and keep a hash of models to avoid reloading)
# (one model per language)
# if model is given as parameter: reload!

sub load_model{
    my $self = shift;
    my ( $lang, $model ) = @_;

    if ( exists $self->{$lang} && ! defined $model){
	$self->{lang} = $lang;
	return $self->{$lang};
    }

    unless (defined $model){
	if (exists $self->{models}->{$lang}){
	    if (exists $self->{models}->{$lang}->{$self->{version}}){
		$model = $self->{models}->{$lang}->{$self->{version}};
	    }
	    else{
		my ($fallback) = reverse sort keys %{$self->{models}->{$lang}};
		$model = $self->{models}->{$lang}->{$fallback};
	    }
	}
	else{
	    ## some kind of error!
	    return undef;
	}
    }
    if ( -e $model ){
	$self->{$lang} = $model = Ufal::UDPipe::Model::load($model);
	if ($self->{$lang}){
	    $self->{lang} = $lang;
	    $self->{tokenizer}->{$lang} = 
		$self->{$lang}->newTokenizer($Ufal::UDPipe::Model::DEFAULT);
	    return $self->{$lang};
	}
    }
    return undef;
}


# split text into sentences

sub sentence_splitter{
    my $self = shift;
    my $text = shift;

    my $lang = $self->{lang} || 'en';
    my $tokenizer = $self->{tokenizer}->{$lang} ||
	return $text;

    $tokenizer->setText($text);
    my @sents = ();
    while ($tokenizer->nextSentence($self->{sentence})) {
	push ( @sents, $self->{text}->writeSentence($self->{sentence}) );
	chomp($sents[-1]);
    }
    return @sents;
}


## TODO: other things like parsing and tagging


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
