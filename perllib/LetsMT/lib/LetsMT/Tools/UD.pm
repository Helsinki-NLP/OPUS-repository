
package LetsMT::Tools::UD;


use strict;
use DB_File;
use DBM_Filter;

use XML::Parser;


my $id     = undef;
my $word   = '';
my $pos    = 0;
my @sent   = ();
my %id2pos = ();


my %sentences;


sub deprel2db{

    my $opusfile = shift(@_);
    my $dbfile   = shift(@_);

    my $db = tie %sentences,"DB_File",$dbfile;

    $db->Filter_Key_Push('utf8');
    $db->Filter_Value_Push('utf8');


    my $XmlParser = new XML::Parser(Handlers => {Start => \&_XmlStart,
						 End => \&_XmlEnd,
						 Char => \&_XmlChar});

    $id     = undef;
    $word   = '';
    $pos    = 0;
    @sent   = ();
    %id2pos = ();

    eval { $XmlParser->parsefile($opusfile); };
    if ($@){
	warn $@;
	print STDERR $_;
    }

    untie %sentences;
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
	# print $id,"\n";
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
