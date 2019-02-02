package LetsMT::Align::Documents;

=head1 NAME

LetsMT::Corpus - find matching documents in a corpus

=head1 DESCRIPTION
=cut

use strict;
use XML::LibXML;
use XML::Simple;

use open qw(:std :utf8);
use utf8;
use Encode qw(decode decode_utf8 is_utf8);

use String::Approx qw/amatch adistr/;
use File::Basename qw/basename dirname/;
use File::Temp 'tempdir';

use LetsMT::Tools;
use LetsMT::Tools::Strings;
use LetsMT::Lang::ISO639;
use LetsMT::WebService;

use Log::Log4perl qw(get_logger :levels);

use Exporter 'import';
our @EXPORT = qw(
    resources_with_identical_names
    resources_with_similar_names
    resources_match_no_lang
    resources_with_language_links
    find_language_links
    extract_language_links
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
    # $response = decode( 'utf8', $response );

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
	    if (@matches>1){
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



## try to find corpus files that only differ in a language name or langids

sub resources_match_no_lang{
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

    ## delete lang names and IDs of all files
    ## and store map back to the full name
    my %map_name = ();
    foreach my $l (keys %corpusfiles){
	foreach my $f (@{$corpusfiles{$l}}){
	    my $name = _delete_language($f,$l);
	    $map_name{$l}{$name} = $f;
	}
    }

    ## save all existing languages for the files in %$parallel
    my %existing_langs = ();
    foreach my $f (keys %{$parallel}){
	$existing_langs{$f} = [];
	foreach my $l (keys %{$$parallel{$f}}){
	    push(@{$existing_langs{$f}},$l);
	}
    }

    ## now find parallel documents
    my $count=0;
    foreach my $f (keys %{$parallel}){

	## try to remove all existing languages from the file
	my $filebase = $f;
	$filebase =~s/\.xml$//;
	foreach my $l (@{$existing_langs{$f}}){
	    $filebase = _delete_language($filebase,$l);
	}

	foreach my $l (@langs){
	    next if (exists $$parallel{$f}{$l});
	    next unless (@{$corpusfiles{$l}});
	    my @matches = grep { $filebase eq $_ } keys %{$map_name{$l}};

	    ## try fuzzy matching if specified
	    unless (@matches){
		if ($args{search_parallel}=~/(similar|fuzzy)/){
		    @matches = amatch( $filebase, keys %{$map_name{$l}} );
		    if (@matches>1){
			my %dist;
			@dist{@matches} = map { abs } adistr( $filebase, @matches );
			@matches = sort { $dist{$a} <=> $dist{$b} } @matches;
		    }
		}
	    }
	    if (@matches){
		$$parallel{$f}{$l} = join( '/',( $slot, $branch, 'xml', $l, $map_name{$l}{$matches[0]}) );
		$$parallel{$f}{$l} .= '.xml';
		$count++;
	    }
	}
    }
    return $count;
}



sub _delete_language{
    my ($str,$langid2) = @_;

    ## remove all occurrences of the langiD in the string
    ## - case-insensitive
    ## - delimitered by non alphanumeric characters
    ## - or at beginning or at the end of the file name
    $str=~s/(\A|\P{Alnum})$langid2(\Z|\P{Alnum})/$1$2/ig;
    $str=~s/(\A|\/)$langid2([^\/]+)/$1$2/ig;
    $str=~s/$langid2(\.[a-z]{2,4}|\Z)/$1/ig;

    ## the same with 3-letter codes
    my $langid3 = iso639_TwoToThree($langid2);
    $str=~s/(\A|\P{Alnum})$langid3(\Z|\P{Alnum})/$1$2/ig;
    $str=~s/(\A|\/)$langid3([^\/]+)/$1$2/ig;
    $str=~s/$langid3(\.[a-z]{2,4}|\Z)/$1/ig;

    ## and finally also the plain name
    ## TODO: also local language names!
    my $lang = iso639_ThreeToName($langid3);
    $str=~s/(\A|\P{Alnum})$lang(\Z|\P{Alnum})/$1$2/ig;
    $str=~s/(\A|\/)$lang([^\/]+)/$1$2/ig;
    $str=~s/$lang(\.[a-z]{2,4}|\Z)/$1/ig;

    ## also delete all non-alphanumeric characters
    ## TODO: is this good to do in general?
    $str=~s/\P{Alnum}+/ /g;

    return $str;
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




sub resources_with_language_links{
    my $corpus   = shift;
    my $parallel = shift || {};
    my %args     = @_;

    my $slot        = $corpus->slot;
    my $branch      = $corpus->user;

    ## make the language-specific resource
    my $xmlres = LetsMT::Resource::make( $slot, $branch, 'xml' );

    ## NEW: just get everything because we also need imported_from
    ## TODO: this can become big ...
    my %query = ( 'resource-type'         => 'corpusfile',
		  type                    => 'recursive',
		  action                  => 'list_all');

    # query the database
    my $response  = LetsMT::WebService::get_meta( $xmlres, %query );
    # $response     = decode( 'utf8', $response );

    my $XmlParser = new XML::LibXML;
    my $dom       = $XmlParser->parse_string( $response );
    my @nodes     = $dom->findnodes('//list/entry');

    my %links = ();
    my %files = ();
    foreach my $n (@nodes){
	my $file = $n->findvalue('@path');
	my $from = $n->findvalue('imported_from');

	## remove tar/zip file from the path of the original file
	## to match them with the linked files
	$from=~s/\/[^\/]+(\.tar|\.tgz|\.tar\.gz|\.zip):/\//;

	## save the new resource file name for each original file
	$files{$from} = $file;

	## find language links and save them
	my @l = split( ',', $n->findvalue('language_links') );
	foreach (@l){
	    my ($lang,$href) = split(/:/);
	    if ($href ne $from){
		$links{$file}{$lang} = $href;
	    }
	}
    }

    ## now we still have to find the linked files
    my $count = 0;
    foreach my $f (keys %links){

	## get the basename of the file (without slot/branch/xml/lang)
        my $newres   = LetsMT::Resource::make_from_storage_path($f);
	my $basename = $newres->basename;

	foreach my $l ( keys %{$links{$f}} ){

	    ## if the linked file exists in the repository:
	    ## --> establish a link between them
	    if (exists $files{$links{$f}{$l}}){
		if ($files{$links{$f}{$l}} ne $f){
		    $$parallel{$basename}{$l} = $files{$links{$f}{$l}};
		    $count++;
		}
	    }
	    ## a hack to fix the problem that the uploads dir is sometimes lost
	    elsif (exists $files{'uploads/'.$links{$f}{$l}}){
		if ($files{'uploads/'.$links{$f}{$l}} ne $f){
		    $$parallel{$basename}{$l} = $files{'uploads/'.$links{$f}{$l}};
		    $count++;
		}
	    }
	}

	## also add the current language version
	if (exists $$parallel{$basename}){
	    my $lang = $newres->language;
	    $$parallel{$basename}{$lang} = $f;
	}

    }
    return $count;
}







## find links in files that have been uploaded
## and look for language links in the data
## add all language links to the metadata of
## resources that have already been imported

sub find_language_links {
    my $resource = shift;
    my $type = shift || 'vnk';

    # Get requested resource if necessary
    if ( ( !-e $resource->local_path ) ) {
	my $tmpdir = tempdir(
	    'findlinks_XXXXXXXX',
	    DIR     => $ENV{LETSMT_TMP},
	    CLEANUP => 1
	    );
	$resource->local_dir($tmpdir);
        return 0 unless ( &LetsMT::WebService::get_resource($resource) );
    }

    ##------------------------------------
    ## collect links
    ##------------------------------------
    my %links = ();

    ## a bit ad-hoc to check whether the resource is a tar-file
    if ($resource->path=~/(\.tar|\.tgz|\.tar\.gz)$/){
	my $localhome = dirname($resource->local_path);
	my $para = $resource->path=~/gz$/ ? '-xzvf' : '-xcf';

	## TODO: do we need this?
	local $ENV{LC_ALL} = 'en_US.UTF-8';
	my $cmd_reader
	    = &LetsMT::Tools::cmd_out_reader( 'tar', $para,
					      &safe_path( $resource->local_path ),
					      '-C',
					      &safe_path( $localhome ) );

	# run through all unpacked resources and import them

	while ( my $exfile = &$cmd_reader ) {
	    chomp $exfile;
	    # $exfile = &utf8_to_perl($exfile);
	    next if ($exfile =~ /\/$/ );              # skip directories
	    next if (basename($exfile)=~/^\./);       # skip files starting with .
	    next unless ($exfile =~ /\.html?$/ );     # only HTML is allowed

	    open F, '<:raw', $localhome. '/'. $exfile;
	    my $html = do { local $/; <F> };
	    close F;

	    my $file = $resource->path.':'.$exfile;
	    %{$links{$file}} = &extract_language_links($html, $file, $type );
	    delete $links{$file} unless (keys %{$links{$file}});
	}
    }
    ## TODO: should also handle zip-files here

    ## html files
    elsif ($resource->path=~/\.html?$/i){
	open F, '<:raw', $resource->local_path;
	my $html = do { local $/; <F> };
	close F;
	%{$links{$resource->path}} = &extract_language_links($html, $resource->path, $type );
	delete $links{$resource->path} unless (keys %{$links{$resource->path}});
    }

    ##------------------------------------
    ## add the information to the metadata
    ##------------------------------------

    my $slot   = $resource->slot;
    my $branch = $resource->user;

    ## make the language-specific resource
    my $xmlres = LetsMT::Resource::make( $slot, $branch, 'xml' );
    my %query = ( 'resource-type' => 'corpusfile',
		  type            => 'recursive',
		  action          => 'list_all');

    # query the database
    my $response  = LetsMT::WebService::get_meta( $xmlres, %query );
    # $response     = decode( 'utf8', $response );

    my $XmlParser = new XML::LibXML;
    my $dom       = $XmlParser->parse_string( $response );
    my @nodes     = $dom->findnodes('//list/entry');

    my $count = 0;
    foreach my $n (@nodes){
	my $file = $n->findvalue('@path');
	my $from = $n->findvalue('imported_from');
	if (exists $links{$from}){
	    my @arr = ();
	    foreach my $l (sort keys %{$links{$from}}){
		push(@arr,$l.':'.$links{$from}{$l});
	    }
	    my $res   = LetsMT::Resource::make_from_storage_path($file);
	    my %meta = ( language_links => join(',',@arr) );
	    &LetsMT::WebService::post_meta( $res, %meta );
	    $count++;
	}
    }
    return $count;
}



## for HTML:
## extract links to translations of the current website
## TODO: add various styles and make options to select them
## ---> quite hard-coded at this moment but difficult to find generic solutions

sub extract_language_links{
    my $html     = shift;
    my $thisfile = shift;
    my $style    = shift;

    my %trans = ();

    ##----------------------------------------------------
    ## helsinki.fi, infofinland.fi style
    ##----------------------------------------------------

    if ($style=~/(helsinki|infofinland)/ || ! $style){
	while ($html=~/<link\s+rel=\"alternate\"\s+hreflang=\"(..)\"\s+href=\"(.*?)\"/sg){
	    my ($lang,$link) = ($1,$2);
	    # $link=~s/https?:\/\/www.helsinki.fi\//\//;
	    $link=~s/https?:\/\/[\/]+\//\//;
	    $trans{$lang} = $link.'.html';
	}
	return %trans if (keys %trans);
    }

    ##----------------------------------------------------
    ## VNK style links on websites
    ## TODO: is this safe enough? (also subject to change)
    ##----------------------------------------------------
    if ($style eq 'vnk' || ! $style){
	if ($html=~/<ul\s+class=\"..\">\s*(<li class=\"..\".*?)\<\/ul/s){
	    my $match = $1;
	    utf8::decode($match); 
	    my @links = split(/\<\/li\>/,$match);
	    foreach (@links){
		my $lang = undef;
		my $link = undef;
		if (/class=\"(..)\"/){
		    $lang = $1;
		}
		if (/href=\"(.*?)\"/){
		    $link = _relative_to_absolute_path($1,$thisfile);;
		}
		## if it's not a link to a missing language version notification
		## and it's not the link to the same page we are at right now
		## ---> add the translation!
		if ($lang && $link!~/missinglanguageversion/){
		    if ($link ne $thisfile){
			$trans{$lang} = $link;
		    }
		}
	    }
	}
    }

    return %trans;
}


sub _relative_to_absolute_path{
    my ($link,$file) = @_;
    unless ($link=~/^\//){
	my @path = split(/\/+/,dirname($file));
	my @parts = split(/\/+/,$link);
	## move up in file system tree
	while ($parts[0]=~/\.\./){
	    pop(@path);
	    shift(@parts);
	}
	$link = join('/',@path,@parts);
    }
    return $link;
}








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
	# $response     = decode( 'utf8', $response );
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




## return array of corpus files in a given language

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
    # $response     = decode( 'utf8', $response );
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
