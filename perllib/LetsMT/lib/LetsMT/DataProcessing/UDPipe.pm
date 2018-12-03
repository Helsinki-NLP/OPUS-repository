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

use XML::Parser;
use XML::Writer;

use LetsMT;
use LetsMT::Lang::ISO639;

our $UDPIPE_MODEL_DIR     = $LetsMT::UDPIPE_MODEL_DIR || '/usr/local/share/UDPipe';
our $UDPIPE_MODEL_VERSION = $LetsMT::UDPIPE_MODEL_VERSION || 'ud-2.0-170801';


sub new {
    my $class = shift;
    my %self  = @_;

    $self{modeldir}   = $UDPIPE_MODEL_DIR unless ($self{modeldir});
    $self{models}     = {};
    $self{tokenizers} = {};

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
	$self->{lang}      = $lang;
	$self->{model}     = $self->{model};
	$self->{tokenizer} = $self->{tokenizer};
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
	$self->{$lang} = Ufal::UDPipe::Model::load($model);
	if ($self->{$lang}){
	    $self->{lang} = $lang;
	    $self->{tokenizers}->{$lang} = 
		$self->{$lang}->newTokenizer($Ufal::UDPipe::Model::DEFAULT);
	    $self->{model}     = $self->{$lang};
	    $self->{tokenizer} = $self->{tokenizers}->{$lang};
	    return $self->{$lang};
	}
    }
    return undef;
}


# split text into sentences
#
# input = raw text string
# returns reference to array of sentences
#
# optional input arguments: $sentarray, $tokenized_sentarray
# - $sentarray = reference to array of sentences (same as return)
# - $tokenized_sentarray = reference to array of tokenized sentences

sub sentence_splitter{
    my $self = shift;
    my $text = shift;

    ## optional: reference to arrays
    ## - sents     = array of untokenized sentences
    ## - tokenized = array of tokenized sentences
    my ($sents,$tokenized) = @_;
    my $sents = [] unless (ref($sents) eq 'ARRAY');

    my $lang = $self->{lang} || 'en';
    my $tokenizer = $self->{tokenizers}->{$lang} ||
	return $text;

    $tokenizer->setText($text);
    @{$sents} = ();
    @{$tokenized} = () if (ref($tokenized) eq 'ARRAY');
    while ($tokenizer->nextSentence($self->{sentence})) {

	## get the raw untokenized text from conllu output
	my $conllu = $self->{conllu}->writeSentence($self->{sentence});
	if ( $conllu =~/# text = ([^\n]*)\n/ ){
	    push ( @{$sents}, $1 );
	}
	else {
	    push ( @{$sents}, $self->_conllu_to_raw($conllu) );
	}

	## get tokenized output from horiozontal output writer
	if (ref($tokenized) eq 'ARRAY'){
	    my $sent   = $self->{text}->writeSentence($self->{sentence});
	    chomp($sent);
	    push ( @{$tokenized}, $sent );
	}
    }
    return $sents;
}


## helper function that converts a conllu 

sub _conllu_to_raw{
    my $self=shift;
    my @lines = split(/\n/,$_[0]);
    my $sent = '';
    foreach (@lines){
	next if (/^\#/);
	if (/\S/){
	    my @f = split(/\t/);
	    $sent .= $f[1];
	    $sent .= ' ' unless ($f[9]=~/SpaceAfter=No/);
	}
	else{
	    $sent .= "\n";
	}
    }
    chomp ($sent);
    return $sent;
}


sub tokenize_raw{
    my $self = shift;
    my $text = shift;

    my $lang = $self->{lang} || 'en';
    $self->load_model($lang) unless (defined $self->{tokenizers}->{$lang});

    ## no model loaded? return $text
    ## TODO: should we have some other fallback method?
    my $tokenizer = $self->{tokenizers}->{$lang} || return $text;

    $tokenizer->setText($text);
    my @sents = ();
    while ($tokenizer->nextSentence($self->{sentence})) {
	push ( @sents, $self->{text}->writeSentence($self->{sentence}) );
	chomp($sents[-1]);
    }
    return @sents;
}


sub tokenize_conllu{
    my $self = shift;
    my $text = shift;

    my $lang = $self->{lang} || 'en';
    $self->load_model($lang) unless (defined $self->{tokenizers}->{$lang});

    ## no model loaded? return undef
    my $tokenizer = $self->{tokenizers}->{$lang} || return undef;

    $tokenizer->setText($text);
    my @sents = ();
    while ($tokenizer->nextSentence($self->{sentence})) {
	push ( @sents, $self->{conllu}->writeSentence($self->{sentence}) );
	chomp($sents[-1]);
    }
    return @sents;
}



## TODO: other things like tagging

sub parse_xml_file{
    my $self      = shift;
    my $infile    = shift;
    my $outfile   = shift || $infile.'.ud';
    my $model     = shift || $self->{model};
    my $tokenizer = shift || $self->{tokenizer};

    open my $out, '>',$outfile || return 0;

    my $XmlParser = new XML::Parser(Handlers => {Start => \&_XmlStart,
						 End => \&_XmlEnd,
						 Char => \&_XmlChar});

    my $XmlWriter = new XML::Writer( OUTPUT      => $out,
				     DATA_MODE   => 1, 
				     DATA_INDENT => 2, 
				     ENCODING    => 'utf-8');

    $XmlParser->{XmlWriter} = $XmlWriter;
    $XmlParser->{UdModel}   = $model;
    $XmlParser->{Tokenizer} = $tokenizer;
    $XmlParser->{Sentence}  = Ufal::UDPipe::Sentence->new();
    $XmlParser->{ConlluOut} = Ufal::UDPipe::OutputFormat::newOutputFormat('conllu');

    # my $XmlReader = $XmlParser->parse_start;
    # $XmlReader->{XmlWriter} = $XmlReader;

    $XmlWriter->xmlDecl();
    eval { $XmlParser->parsefile($infile); };
    if ($@){
	warn $@;
	print STDERR $_;
    }
}



sub _XmlStart{
    my ($p,$e,%a) = @_;
    if ($e eq 's'){
	$$p{SENT} = '';
	$$p{SENTID} = $a{id};
	$$p{WIDBASE} = $a{id};
	$$p{WIDBASE} =~s/^s/w/;
	$$p{TAGS} = [];
	$p->{XmlWriter}->startTag($e,%a);
    }
    else{
	unless (exists $$p{SENT}){
	    $p->{XmlWriter}->startTag($e,%a);
	}
	## save sentence-internal tags
	else{
	    my $idx = @{$$p{TAGS}};
	    $$p{TAGS}[$idx]{tag} = $e;
	    %{$$p{TAGS}[$idx]{attr}} = %a;
	    $$p{TAGS}[$idx]{type} = 'open';
	    $$p{TAGS}[$idx]{after} = $$p{SENT};
	    $$p{TAGS}[$idx]{after}=~s/\s+//sg;
	}
    }
}

sub _XmlEnd{
    my ($p,$e) = @_;
    if ($e eq 's'){

	$$p{SENT}=~s/^\s*//;
	$$p{SENT}=~s/\s*$//;
	$p->{Tokenizer}->setText($$p{SENT});
	delete $$p{SENT};
	my $nrSent=0;
	my $sentStr = '';

	while ($p->{Tokenizer}->nextSentence($p->{Sentence})) {

	    $p->{UdModel}->tag($p->{Sentence}, $Ufal::UDPipe::Model::DEFAULT);
	    $p->{UdModel}->parse($p->{Sentence}, $Ufal::UDPipe::Model::DEFAULT);
	    my $processed = $p->{ConlluOut}->writeSentence($p->{Sentence});

	    ## just in case the tokeniser found additional sentence breaks
	    if ($nrSent){
		$p->{XmlWriter}->emptyTag('sentBreak');
	    }
	    $nrSent++;

	
	    my @lines = split(/\n/,$processed);
	    foreach my $line (@lines){
		next if ($line=~/^\#/);
		my ($id,$word,$lemma,$upos,$xpos,$feats,$head,$deprel,$deps,$misc) 
		    = split(/\t/,$line);

		&_insert_tags($p->{XmlWriter},$sentStr,$word,$$p{TAGS});
		$sentStr .= $word;
		$sentStr=~s/\s+//sg; ## do we need this?

		## TODO: do something more clever with multi-span tokens
		next if ($id=~/\-/);
		my %attr = (id => "$$p{WIDBASE}.$id");
		$attr{lemma}=$lemma unless ($lemma eq '_');
		$attr{upos}=$upos unless ($upos eq '_');
		$attr{xpos}=$upos unless ($xpos eq '_');
		$attr{feats}=$feats unless ($feats eq '_');
		## good to have real word IDs (in case we have multiple sentences 
		## in one unit
		if ($head eq '0'){
		    $attr{head} = 0;
		}
		else{
		    $attr{head}="$$p{WIDBASE}.$head" unless ($head eq '_');
		}
		# $attr{head}="$$p{WIDBASE}.$head" unless ($head eq '_');
		$attr{deprel}=$deprel unless ($deprel eq '_');
		$attr{secdep}=$deps unless ($deps eq '_');
		$attr{misc}=$misc unless ($misc eq '_');
		$p->{XmlWriter}->startTag('w',%attr);
		$p->{XmlWriter}->characters($word);
		$p->{XmlWriter}->endTag('w');

		&_insert_tags($p->{XmlWriter},$sentStr,' ',$$p{TAGS});

	    }
	}

	if (@{$$p{TAGS}}){
	    print STDERR "Warning: remaining tags found:";
	    foreach my $t (@{$$p{TAGS}}){
		print "tag = $$t{tag} ($$t{type})\n";
	    }
	}

	$p->{XmlWriter}->endTag($e);
    }
    else{
	unless (exists $$p{SENT}){
	    $p->{XmlWriter}->endTag($e);
	}
	else{
	    my $idx = @{$$p{TAGS}};
	    $$p{TAGS}[$idx]{tag} = $e;
	    $$p{TAGS}[$idx]{type} = 'close';
	    $$p{TAGS}[$idx]{after} = $$p{SENT};
	    $$p{TAGS}[$idx]{after}=~s/\s+//sg;
	}
    }
}

sub _XmlChar{
    my ($p,$c) = @_;
    $$p{SENT}.=$c if (exists $$p{SENT});
}



sub _insert_tags{
    my ($XmlWriter,$before,$next,$tags)=@_;

    while (@{$tags}){

	## check if we should insert a tag
	## - string before matches
	## - token-internal tags: put start-tag before the next token
	##                        put end-tag after
	my $insert = 0;
	if ($before eq $$tags[0]{after}){
	    $insert = 1;
	}
	elsif (length("$before$next") <= length($$tags[0]{after})){
	    return;  # tags should be sorted by increasing length
	}
	## token-internal tags (index should be 0 but 
	elsif (index("$before$next",$$tags[0]{after})>=0){
	    $insert = 1 if ($$tags[0]{type} eq 'open');
	}
	elsif (index($before,$$tags[0]{after})>=0){
	    $insert = 1 if ($$tags[0]{type} eq 'close');
	}

	if ($insert){
	    if ($$tags[0]{type} eq 'open'){
		## same place as next closing tag? --> write empty tag
		if ($$tags[0]{after} eq $$tags[1]{after}){
		    $XmlWriter->emptyTag($$tags[0]{tag},
					 %{$$tags[0]{attr}});
		    shift(@{$tags});
		}
		else{
		    $XmlWriter->startTag($$tags[0]{tag},
					 %{$$tags[0]{attr}});
		}
	    }
	    elsif ($$tags[0]{type} eq 'close'){
		$XmlWriter->endTag($$tags[0]{tag});
	    }
	    shift(@{$tags});
	}
	else{
	    return;
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
