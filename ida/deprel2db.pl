#!/usr/bin/env perl

use strict;
use DB_File;
use DBM_Filter;

use XML::Parser;

my $opusfile = shift(@ARGV);
my $dbfile   = shift(@ARGV);



my %sentences;
my $db = tie %sentences,"DB_File",$dbfile;

$db->Filter_Key_Push('utf8');
$db->Filter_Value_Push('utf8');


my $XmlParser = new XML::Parser(Handlers => {Start => \&_XmlStart,
					     End => \&_XmlEnd,
					     Char => \&_XmlChar});

my $id     = undef;
my $word   = '';
my $pos    = 0;
my @sent   = ();
my %id2pos = ();

eval { $XmlParser->parsefile($opusfile); };
if ($@){
    warn $@;
    print STDERR $_;
}


sub _XmlStart{
    my ($p,$e,%a) = @_;
    if ($e eq 's'){
	$id   = $a{id};
	$pos  = 0;
    }
    elsif ($e eq 'w'){
	$pos++;
	$id2pos{$a{id}} = $pos;
	push(@sent,[]);
	foreach my $f ('lemma', 'upos', 'xpos', 'feats', 'head', 'deprel', 'deps', 'misc'){
	    push(@{$sent[-1]},$a{$f});
	    if (not defined $sent[-1][6]){
		$sent[-1][6] = 0 if ($a{head} eq "0");
	    }
	}
    }
}



sub _XmlEnd{
    my ($p,$e) = @_;
    if ($e eq 's'){
	foreach my $w (0..$#sent){
	    $sent[$w][6] = $id2pos{$sent[$w][6]};
	}
	my $str = '';
	foreach my $w (0..$#sent){
	    $str .= join("\t",@{$sent[$w]});
	    $str .= "\n";
	}
	$sentences{$id} = $str;
	print $id,"\n";
	@sent   = ();
	%id2pos = ();
    }
    elsif ($e eq 'w'){
	$word=~s/^\s*//;$word=~s/\s*$//;
	unshift(@{$sent[-1]},$word);
	unshift(@{$sent[-1]},$pos);
	$word = '';
    }
}

sub _XmlChar{
    my ($p,$c) = @_;
    $word.=$c;
}
