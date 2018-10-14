package LetsMT::Align::Documents;

=head1 NAME

LetsMT::Corpus - find matching documents in a corpus

=head1 DESCRIPTION
=cut

use strict;
use XML::LibXML;
use XML::Simple;

use open qw(:std :utf8);
use Encode qw(decode decode_utf8 is_utf8);

use String::Approx qw/amatch adistr/;
use File::Basename qw/basename dirname/;

use LetsMT::Tools::Strings;
use LetsMT::Lang::ISO639;
use LetsMT::WebService;


use Log::Log4perl qw(get_logger :levels);

use Exporter 'import';
our @EXPORT = qw(
    resources_with_identical_names
    resources_with_similar_names
);
our %EXPORT_TAGS = ( all => \@EXPORT );




sub resources_with_identical_names{
    my $corpus   = shift;
    my $parallel = shift || {};
    my $filename = shift;

    ## query the meta database
    my %query = ( 'resource-type'  => 'corpusfile',
		  type             => 'recursive' );
    $query{'ENDS_WITH__ID_'} = $filename if ($filename);
    my $response = LetsMT::WebService::get_meta( $corpus, %query );
    $response = decode( 'utf8', $response );

    ## parse the query result (matching files in entry-path)
    my %files     = ();
    my $XmlParser = new XML::LibXML;
    my $dom       = $XmlParser->parse_string($response);
    my @nodes     = $dom->findnodes('//list/entry/@path');

    foreach my $n (@nodes) {
        my $file     = $n->to_literal;
        my $newres   = LetsMT::Resource::make_from_storage_path($file);
	my $lang     = $newres->language;
	my $basename = $newres->basename;
        unless ( $filename && ($basename ne $filename) ) {
	    $$parallel{$basename}{$lang} = $file;
        }
    }
    return $parallel;
}



## try to find corpus files with similar names
## for languages that do not have a match yet in the given 
## hash of parallel documents

sub resources_with_similar_names{
    my $corpus   = shift;
    my $parallel = shift || {};
    my %args     = @_;

    return 0 unless (keys %{$parallel});

    ## get languages that we need to look for
    my @langs = &_get_missing_languages( $corpus, $parallel, %args );

    my $slot        = $corpus->slot;
    my $branch      = $corpus->user;
    my %corpusfiles = ();
    foreach my $l (@langs){
	@{$corpusfiles{$l}} = &_get_language_documents( $slot, $branch, $l );
    }

    ## run through the document base names
    ## and find similar files for the languages that are missing
    my $count = 0;
    foreach my $f (keys %{$parallel}){

	# my $filebase = basename($f);
	# my $filedir  = dirname($f);
	my $filebase = $f;
	$filebase =~s/\.xml$//;
	next unless (basename($filebase)=~/\p{L}/);  # skip file names without any letters

	foreach my $l (@langs){
	    next if (exists $$parallel{$f}{$l});
	    next unless (@{$corpusfiles{$l}});
	    my @matches = amatch( $filebase, @{$corpusfiles{$l}} );
	    # more than 1? sorting according to distance!
	    # see https://metacpan.org/pod/String::Approx
	    if ($#matches){
		my %dist;
		@dist{@matches} = map { abs } adistr( $filebase, @matches );
		@matches = sort { $dist{$a} <=> $dist{$b} } @matches;
	    }
	    if (@matches){
		$matches[0] .= '.xml';
		$$parallel{$f}{$l} = join( '/',( $slot, $branch, 'xml', $l, $matches[0]) );
		$count++;
	    }
	}
    }
    return $count;
}



## try to find corpus files with translated names
## for languages that do not have a match yet in the given 
## hash of parallel documents
## ---> use word alignment and pre-trained priors for eflomal

sub resources_with_translated_names{
    my $corpus   = shift;
    my $parallel = shift || {};
    my %args     = @_;

    return 0 unless (keys %{$parallel});

    ## get languages that we need to look for
    my @langs = &_get_missing_languages( $corpus, $parallel, %args );

    my $slot        = $corpus->slot;
    my $branch      = $corpus->user;
    my %corpusfiles = ();
    foreach my $l (@langs){
	@{$corpusfiles{$l}} = &_get_language_documents( $slot, $branch, $l );
    }

    ## turn filenames into space-separated strings (pseudo-sentences)
    my %sent2file = ();
    foreach my $l (keys %corpusfiles){
	foreach my $f (@{$corpusfiles{$l}}){
	    my $sent = $f;
	    $sent=~s/\.xml$//;
	    $sent=~s/\P{Alnum}/ /g;
	    $sent2file{$l}{$sent} = $f;
	}
    }


    ## get all language-pairs and sentence to be aligned

    my %need2align = ();
    foreach my $f (keys %{$parallel}){

	## TODO: is that good enough to use the first
	##       language as source language?
	my ($srclang) = sort keys %{$$parallel{$f}};
	my $srcsent   = $$parallel{$f}{$srclang};
	$srcsent=~s/\.xml$//;
	$srcsent=~s/\P{Alnum}/ /g;

	foreach my $l (@langs){
	    next if (exists $$parallel{$f}{$l});
	    next unless (@{$corpusfiles{$l}});
	    $need2align{$srclang}{$l}{$srcsent} = $f;
	}
    }

    foreach my $s (keys %need2align){
	foreach my $t (keys %{$need2align{$s}}){

	    ## make alignment data: all combinations of all src sentences 
	    ## with target doc names (keys %{$sent2file{$l}})

	    ## open tmpfile
	    ## my @trgsents = keys %{$sent2file{$t}};
	    ## foreach my $srcsent (keys %{$need2align{$s}{$t}}){
	    ##     print_combinations($srcsent,@trgsents);
	    ## }

	    ## align everything
	    ## get best matches for each source sentence
	    ## set the corresponding thing in $parallel

	}
    }


    # return $count;
}


# ## TODO: this is not very efficient to do that with each and every file

# sub _alignment_ranking{
#     my $srclang = shift;
#     my $trglang = shift;
#     my $srcsent = shift;
#     my @trgsents = @_;

#     ## find priors for the given language pair
#     ## make input data to align with eflomal
#     ## run eflomal and get alignment scores

# }



## return array of language IDs that are missing in some of the
## parallel resources in the given hash of files

sub _get_missing_languages{
    my $corpus   = shift;
    my $parallel = shift || {};
    my %args     = @_;

    ## check whether languages are given as an argument
    my @langs = ();
    if (exists $args{languages}){
	if (ref($args{languages}) eq 'ARRAY'){
	    @langs = @{$args{languages}};
	}
	else{
	    @langs = split(/\,/,$args{languages});
	}
    }

    ## otherwise: get all registered languages in the corpus
    else{
	my $response  = &LetsMT::WebService::get_meta( $corpus );
	$response     = decode( 'utf8', $response );
	my $XmlParser = new XML::LibXML;
	my $dom       = $XmlParser->parse_string( $response );
	my @nodes     = $dom->findnodes('//list/entry');
	@langs        = split( /,/, $nodes[0]->findvalue('langs') );
    }

    ## for each file base in parallel: check whether a language is missing
    ## and collect all those languages

    my %missing = ();
    foreach my $f (keys %{$parallel}){
	my $filebase = basename($f);
	$filebase =~s/\.xml$//;
	next unless ($filebase=~/\p{L}/);  # skip names without any letters
	foreach my $l (@langs){
	    $missing{$l}++ unless (exists $$parallel{$f}{$l});
	}
    }

    return keys %missing;
}




## return array corpus files in a given language

sub _get_language_documents{
    my $slot     = shift;
    my $branch   = shift;
    my $lang     = shift;

    ## make the language-specific resource
    my $langres = LetsMT::Resource::make( $slot, $branch, 'xml/'.$lang );

    ## get all files for all languages with missing documents
    my %query = ( 'resource-type'  => 'corpusfile',
		  type             => 'recursive' );

    # query the database
    my $response  = LetsMT::WebService::get_meta( $langres, %query );
    $response     = decode( 'utf8', $response );
    my %files     = ();
    my $XmlParser = new XML::LibXML;
    my $dom       = $XmlParser->parse_string($response);
    my @nodes     = $dom->findnodes('//list/entry/@path');

    my @documents = ();
    foreach my $n (@nodes) {
	my @path = split( /\/+/, $n->to_literal );
	shift(@path); # slot
	shift(@path); # branch
	shift(@path); # xml
	shift(@path); # lang
	if (@path){
	    $path[-1]=~s/\.xml$//;
	    push(@documents,join('/',@path));
	}
    }
    return @documents;
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
