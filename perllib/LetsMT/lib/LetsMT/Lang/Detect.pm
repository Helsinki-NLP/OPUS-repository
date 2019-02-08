# -*-perl-*-

package LetsMT::Lang::Detect;

=head1 NAME

LetsMT::Lang::Detect

=cut

use strict;

use Exporter 'import';
our @EXPORT = qw( detect_language detect_language_string create_lm );
our %EXPORT_TAGS = ( all => \@EXPORT );

use Benchmark;

use Encode qw(encode);
use File::Temp qw(tempfile tempdir);
use File::ShareDir 'dist_dir';

## NEW: get rid of blacklist classifier
##      takes too much time for loading models
# use Lingua::Identify::Blacklists qw/:all/;

## CLD2 module does not build correcly!
# use Lingua::Identify::CLD2;
use Lingua::Identify::CLD;
use Lingua::Identify qw(:language_identification);

## for the langid server that served clds and langid.py
use IO::Socket::INET;
use IO::Select;

use LetsMT::Lang::ISO639 qw / :all /;
use LetsMT::Tools qw /:all/;

use LetsMT::Export::Reader;
use LetsMT::Export::Writer;

use Log::Log4perl qw(get_logger :levels);


#################################################################
## Inline Python does not seem to work with apache and mod_perl
## at least when importing other libraries
#################################################################
#
# use Inline::Python;                         # for CLD2 bindings!
#
## call cld2 language identifier
## input arguments: textstring, assumed_language
##          output: langid, isReliable, details
##
## help on pycld2:
##    python -c "import pycld2 as cld2; help(cld2.detect)"
##
## other options:
##   bestEffort=True
#
# use Inline Python => <<'END_OF_PYTHON_CODE';
#
# import pycld2 as cld2
# import langid
# from langid.langid import LanguageIdentifier, model
# identifier = LanguageIdentifier.from_modelstring(model, norm_probs=True)

## import sys
## sys.path.append('/usr/local/lib/python3.4/dist-packages')
# def detect_with_cld2(s,l=""):
#      return 'en'
#     if (l != ""):
#        isReliable, textBytesFound, details = cld2.detect(s, hintLanguage=l)
#     else:
#        isReliable, textBytesFound, details = cld2.detect(s)
#     return (details[0][1],isReliable,details)
# def detect_with_langid(s):
#     return identifier.classify(s)
# END_OF_PYTHON_CODE
#################################################################


our $LM_HOMEDIR = &dist_dir('LetsMT') . '/lang/textcat';

our $MAX_TEXT_SIZE = 65536;    # max text size read for detection (in bytes)
our $MIN_TEXT_SIZE = 512;      # min text size used for detection
our $MAX_DATA      = 100;      # max number of data records to be read
our $BOILER_PLATE_SIZE = 8148; # estimated max size of a boiler plate

# our $LANGUAGE_IDENTIFIER = 'textcat';
# our $LANGUAGE_IDENTIFIER = 'cld';
# our $LANGUAGE_IDENTIFIER = 'cld2';
our $LANGUAGE_IDENTIFIER = 'default';


## the compact language identifier from Google Chrome
my $CLD = new Lingua::Identify::CLD;


# this is mainly copied from textcat ......

my $NrAltClass     ||= 10;
my $TopNgrams      ||= 400;
my $AltClassFactor ||= 1.05;
my $FreqThr          = 0;
my $non_word_characters = '0-9\s';

my $VERBOSE = 0;

# hash that holds all language models
# load all models!
my %ngram = ();

## don't load models automatically
# load_models();




#-------------------------------------------
# classify a resource, a file or a string
#-------------------------------------------

sub detect_language {
    my $data = shift;
    my %args = @_;

    if (ref($data)){
        return classify_resource($data,@_);
    }
    if (-e $data){
	return classify_text($data,@_);
    }
    my $lang = detect_language_string($data, 
				      $args{langhint}, 
				      $args{classifier}, @_);
    return wantarray ? ($lang) : $lang;
}



## detect language in a string
## default classifier is langid.py
##
## $lang = detect_language_string( $string, $lang_hint, $classifier [,%args] )
##
## $lang_hint is an optional lang ID that is expected from the input
## $classifier = classifer to be used

sub detect_language_string {
    my $string = shift   || return undef;
    my $hint   = shift   || undef;
    my $method = shift   || $LANGUAGE_IDENTIFIER;
    if ( $method eq 'cld' ){
	return &detect_language_with_cld($string, $hint, @_);
    }
    elsif ( $method eq 'cld2' ){
	return &detect_language_with_cld2($string, $hint, @_);
    }
    # elsif ( $method eq 'blacklist' ){
    # 	return &identify($string, $hint, @_);
    # }
    elsif ( $method eq 'lingua' ){
	return &detect_language_with_lingua($string, $hint, @_);
    }
    elsif ( $method eq 'textcat' ){
	return &detect_language_with_textcat($string, @_);
    }
    return &detect_language_with_langid($string, $hint, @_);
}




=head2 C<classify_text>

 @answers = &classify_text ($file [,%args])

  classifier        => textcat|cld|cld2|lingua|langid
  max_text_size     => <max_size_to_read>
  boiler_plate_size => <estimated_size_of_boiler_plates>

Additional options for specific classifiers are possible, for example

  lm_dir => <LM_model_directory_for_textcat>

=cut


sub classify_text {
    my $file = shift;
    my %args = @_;

    my $classifier        = $args{classifier}        || $LANGUAGE_IDENTIFIER;
    my $max_text_size     = $args{max_text_size}     || $MAX_TEXT_SIZE;
    my $boiler_plate_size = $args{boiler_plate_size} || $BOILER_PLATE_SIZE;

    # # Lingua::Identify::Blacklists
    # if ( $classifier eq 'blacklist' ){
    # 	my $lang = &identify_file( $_[0] );
    # 	return wantarray ? ($lang) : $lang;
    # }

    ##----------------------------------------------
    ## for other classifiers: first read some text 
    ## and then classify that string
    ##----------------------------------------------

    # read input from the file to be classified
    if   ( $file =~ /\.gz/ ) { open F, "gzip -cd <$file |"; }
    else                     { open F, "<$file"; }

    ## TODO: what encoding do we actually need? or raw text?
    ##       is this different for each classifier?
    # binmode(F);
    binmode(F, ":utf8");
    my $text;
    read( *F, $text, $max_text_size );
    close F;

    ## if there is enough text: remove some data that might be a boiler plate
    if ( length($text)-2*$boiler_plate_size > $max_text_size/2 ){
	$text = substr( $text, $boiler_plate_size, 0-$boiler_plate_size);
    }


    ## classify the string using the selected classifier
    my $lang = &detect_language_string($text,$args{langhint},$classifier);
    return wantarray ? ($lang) : $lang;
}






## this is a bit silly on resources with more than one language!

sub classify_resource {
    my $resource = shift or die("Missing resource!\n");
    my %args = @_;

    my $max_data = $args{max_data} || $MAX_DATA;

    ## if the resource is a plain text: just send it to the classifier
    my $type = $resource->type;
    if ($type=~/(txt|text)/){
	return classify_text($resource->local_path,@_);
    }

    ## otherwise: try to read from the resource
    print STDERR "unknown format" unless ($type);
    my $input = new LetsMT::Export::Reader( $resource, $type );
    $input->open($resource);

    # NEW: don't actually create a text but just get the string
    my $string = '';

    my $reader = new LetsMT::Export::Reader($resource);
    my $writer = new LetsMT::Export::Writer(undef,'text');

    $reader->open();
    my $count=0;
    while (my $data = $reader->read ){
	if ( ref($data) eq 'HASH' ) {
	    my $str = '';
	    foreach my $l ( keys %{$data} ) {
		$str .= $writer->to_string( $$data{$l} )."\n";
	    }
	    if ( $str=~/\S/ ){
		$string .= $str;
		$count++;
		last if (length($string) >= $MAX_TEXT_SIZE );
		last if ($count >= $max_data && 
			 length($string) >= $MIN_TEXT_SIZE );
	    }
	}
    }
    $reader->close();
    
    ## if we have enough data - remove some part in the beginning
    ## (possible boile plate)
    if ( length($string)-2*$BOILER_PLATE_SIZE > $MAX_TEXT_SIZE/2 ){
	$string = substr( $string, $BOILER_PLATE_SIZE, 0-$BOILER_PLATE_SIZE);
    }

    my $lang = detect_language_string($string,@_);
    return wantarray ? ($lang) : $lang;
}


### the following method does not work because the Moses Writer does not
### support anything else then 2 languages in parallel ....

sub classify_resource_multi {
    my $resource = shift;

    print STDERR "unknown format" unless ($resource->type);

    my $input = new LetsMT::Export::Reader($resource);
    $input->open($resource);

    # make a temporary resource for writing plain text to be classified
    my $tmpdir = tempdir(
        'langdetect_XXXXXXXX',
        DIR     => '/tmp',
        CLEANUP => 1
    );
    my $tmpfile = 'moses';

    # the temporary resource = moses format (allow multiple languages)
    my $temp_resource = new LetsMT::Resource(
        local_dir => $tmpdir,
        path => $tmpfile
    );

    my $output = new LetsMT::Export::Writer( $temp_resource, 'moses' );

    # read a number of data records ....
    my $count = 0;
    while ( my $data = $input->read ) {
        $output->write($data);
        $count++;
        last if ($count>=$MAX_DATA);
    }
    $input->close;
    $output->close;

    # .... language detection on all files ....

    my %detected  = ();
    my @resources = $output->get_resources();
    foreach my $res (@resources){
        my $lang = $res->lang();
        my $file = $res->local_path();
        @{$detected{$lang}} = classify_text($file);
        unlink($file);
    }
    return %detected;
}






########################################################################
# detect language for strings using specific classifiers
########################################################################



sub detect_language_with_cld {
    my $string = shift;
    my $hint = shift || undef;

    my %para = ();
    if ($hint){ $para{'tld'} = $hint; }
    my ($lang, $id, $conf, $isReliable) = $CLD->identify( $string, %para );
    $conf /= 100;

    # strangely enough CLD is not really reliable for English
    # (all kinds of garbish input is recognized as English)
    # --> check with Lingua::Identify
    # if ($id eq 'en'){
    #     ($id,$conf) = langof( $string );
    # }
    return wantarray ? ($id, $conf, $isReliable) : $id;
}

sub detect_language_with_lingua {
    my $string = shift;
    # my @all_languages = get_all_languages();
    my ($id,$conf) = langof( $string );
    return wantarray ? ($id, $conf) : $id;
}


# get langid classifications from langid server
# from http://xmodulo.com/how-to-write-simple-tcp-server-and-client-in-perl.html 
sub detect_language_with_langid {
    # auto-flush on socket
    $| = 1;
 
    # create a connecting socket
    my $socket = new IO::Socket::INET (
	PeerHost => 'localhost',
	PeerPort => '15555',
	Proto => 'tcp',
	Timeout => 5,
	);

    ## fallback to cld classifier
    return &detect_language_with_cld(@_) unless $socket;

    ## TODO: is that what we want?
    $socket->blocking(0);

    my $size = $socket->send(encode('utf8',$_[0], sub{ return  ' ' }));
    # print "sent data of length $size\n";
    $socket->send("\nCLASSIFIER=langid\n");
    $socket->send('<<<CLASSIFY>>>');
    shutdown($socket, 1);

    # receive a response of up to 1024 characters from server
    my $response = "";
    my $sel = new IO::Select ($socket);
    my $timeout = 5;
    if (my @socks = $sel->can_read($timeout)) {
	# $socket = shift(@socks);
	$socket->recv($response, 1024);
    }
    else{
	my $logger = get_logger(__PACKAGE__);
        $logger->warn("langid server timeout - try CLD instead");
	return &detect_language_with_cld(@_);
    }
    $socket->close();
    # print "received response: $response\n";

    if ($response){
	my @ret = eval($response);
	return wantarray ? @ret : $ret[0];
    }

    return &detect_language_with_cld(@_);
}


# get cld2 classifications from langid server
sub detect_language_with_cld2 {
    # auto-flush on socket
    $| = 1;
 
    # create a connecting socket
    my $socket = new IO::Socket::INET (
	PeerHost => 'localhost',
	PeerPort => '15555',
	Proto => 'tcp',
	Timeout => 5,
	);

    ## fallback to cld classifier
    return &detect_language_with_cld(@_) unless $socket;

    # $PerlIO::encoding::fallback = Encode::FB_PERLQQ;
    my $size = $socket->send(encode('utf8',$_[0], sub{ return  ' ' }));
    # print "sent data of length $size\n";
    $socket->send("\nCLASSIFIER=cld2\n");
    $socket->send("LANGHINT=$_[1]\n") if ($_[1]);
    $socket->send('<<<CLASSIFY>>>');
    shutdown($socket, 1);
 
    # receive a response of up to 1024 characters from server
    my $response = "";
    my $sel = new IO::Select ($socket);
    my $timeout = 5;
    if (my @socks = $sel->can_read($timeout)) {
	# $socket = shift(@socks);
	$socket->recv($response, 1024);
    }
    else{
	my $logger = get_logger(__PACKAGE__);
        $logger->warn("langid server timeout - try CLD instead");
	return &detect_language_with_cld(@_);
    }
    # print "received response: $response\n";
    $socket->close();

    if ($response){
	# $response=~tr/\(\)/\[\]/;
	$response=~s/(true|false)/'$1'/i;
	my @ret = eval($response);
	$ret[1] /= 100;
	return wantarray ? @ret : $ret[0];
    }

    return &detect_language_with_cld(@_);
}



## Python bindings do not work!

# sub detect_language_with_cld2 {
#     my $string = shift;
#     my $langhint = shift || "";
#     my ($lang, $isReliable, $details) = detect_with_cld2($string,$langhint);
#     return wantarray ? ($lang, $isReliable, $details) : $lang;
# }

# sub detect_language_string_with_langid {
#     my $string = shift;
#     my $langhint = shift || "";
#     my ($lang, $conf) = detect_with_langid($string,$langhint);
#     return wantarray ? ($lang, $conf) : $lang;
# }




# # classify with langid (require utf8 encoded text!)
# # (TODO: or should it rather be in bytes?)

# sub classify_with_langid{
#     my $file   = shift;
#     # read input
#     if   ( $file =~ /\.gz/ ) { open F, "gzip -cd <$file |"; }
#     else                     { open F, "<$file"; }
#     # binmode(F);
#     binmode(F, ":utf8");
#     my $input;
#     read( *F, $input, $MAX_TEXT_SIZE );
#     close F;
#     ## if there is enough text: remove some data that might be a boiler plate
#     if ( length($input)-2*$BOILER_PLATE_SIZE > $MAX_TEXT_SIZE/2 ){
# 	$input = substr( $input, $BOILER_PLATE_SIZE, 0-$BOILER_PLATE_SIZE);
#     }
#     return &detect_language_with_langid($input);
# }


# classifify with our own textcat models

sub detect_language_with_textcat {
    my $input  = shift;
    my %args   = @_;

    my $LMs    = $args{lm_dir} || $LM_HOMEDIR;
    my $models = $args{models} || \%ngram;

    my %results = ();
    my $maxp    = $TopNgrams;

    # load models if necessary
    load_models($LMs,$models) unless ( keys %{$models} );

    ## TODO: is this correct? 
    $input = encode('utf8',$_[0], sub{ return  ' ' });

    # create ngrams for input. Note that hash %unknown is not used;
    # it contains the actual counts which are only used under -n: creating
    # new language model (and even then they are not really required).
    my @unknown = create_lm($input);

    # load model and count for each language.
    my $language;
    my $t1 = new Benchmark;
    foreach $language ( keys %{$models} ) {

        # compares the language model with input ngrams list
        my ( $i, $p ) = ( 0, 0 );
        while ( $i < @unknown ) {
            if ( $$models{$language}{ $unknown[$i] } ) {
                $p = $p + abs( $$models{$language}{ $unknown[$i] } - $i );
            }
            else {
                $p = $p + $maxp;
            }
            ++$i;
        }

        #print STDERR "$language: $p\n" if $VERBOSE;
        $results{$language} = $p;
    }
    print STDERR "read language models done ("
        . timestr( timediff( new Benchmark, $t1 ) ) . ".\n"
        if $VERBOSE;
    my @results = sort { $results{$a} <=> $results{$b} } keys %results;

    print join( "\n", map { "$_\t $results{$_}"; } @results ), "\n"
        if $VERBOSE;
    my $a = $results{ $results[0] };

    my @answers = ( shift(@results) );
    while ( @results && $results{ $results[0] } < ( $AltClassFactor * $a ) ) {
        @answers = ( @answers, shift(@results) );
    }
    if ( @answers > $NrAltClass ) {
        return wantarray ? ('unknown') : 'unknown';

        # return "I don't know; " .
        #     "Perhaps this is a language I haven't seen before?\n";
    }
    map ( $_ = iso639_AnyToTwo($_), @answers );
    return wantarray ? @answers : $answers[0];
}




########################################################################
# textcat functions
########################################################################


=head2 C<create_lm>

 @models = &create_lm ($text, $lang, $overwrite)

=cut


## this is only used by text_cat

sub create_lm {
    my $t1 = new Benchmark;
    my ( $text, $lang, $overwrite ) = @_;

    # $ngram contains reference to the hash we build
    # then add the ngrams found in each word in the hash
    my $ngram = {};

    my $word;
    foreach $word ( split( "[$non_word_characters]+", $text ) ) {
        $word = "_" . $word . "_";
        my $len  = length($word);
        my $flen = $len;
        my $i;
        for ( $i = 0; $i < $flen; $i++ ) {
            $$ngram{ substr( $word, $i, 5 ) }++ if $len > 4;
            $$ngram{ substr( $word, $i, 4 ) }++ if $len > 3;
            $$ngram{ substr( $word, $i, 3 ) }++ if $len > 2;
            $$ngram{ substr( $word, $i, 2 ) }++ if $len > 1;
            $$ngram{ substr( $word, $i, 1 ) }++;
            $len--;
        }
    }
    ###print "@{[%$ngram]}";
    my $t2 = new Benchmark;
    print STDERR "count_ngrams done ("
        . timestr( timediff( $t2, $t1 ) ) . ").\n"
        if $VERBOSE;

    # as suggested by Karel P. de Vos, k.vos@elsevier.nl, we speed up
    # sorting by removing singletons
    map {
        my $key = $_;
        if ( $$ngram{$key} <= $FreqThr ) { delete $$ngram{$key}; }
    } keys %$ngram;

    #however I have very bad results for short inputs, this way

    # sort the ngrams, and spit out the $TopNgrams frequent ones.
    # adding  `or $a cmp $b' in the sort block makes sorting five
    # times slower..., although it would be somewhat nicer (unique result)
    my @sorted = sort { $$ngram{$b} <=> $$ngram{$a} } keys %$ngram;
    splice( @sorted, $TopNgrams ) if ( @sorted > $TopNgrams );
    print STDERR "sorting done ("
        . timestr( timediff( new Benchmark, $t2 ) ) . ").\n"
        if $VERBOSE;

    # print LM to file

    if ($lang) {
        my $id2     = &iso639_AnyToTwo($lang);
        my $id3     = &iso639_TwoToThree($id2);
        my $lm2file = $LM_HOMEDIR . '/' . $id2 . '.lm';
        my $lm3file = $LM_HOMEDIR . '/' . $id3 . '.lm';
        unless ($overwrite) {
            if ( -e $lm2file || -e $lm3file ) {
                print STDERR "\nLM for '$lang' exists ($lm2file)!\n";
                $lm2file = $id2 . '.lm';
                die "\nLocal LM file exists ($lm2file)!\n" if ( -e $lm2file );
                print STDERR "\nThe language model will be saved in $lm2file";
                print STDERR " in your current directory!\n";
                print STDERR "\nYou need to install it by moving it to \n";
                print STDERR "$LM_HOMEDIR/\n";
            }
        }
        unless (open( F, ">", $lm2file )){
            $lm2file = $id2 . '.lm';
            open( F, ">", $lm2file ) || 
                die "cannot open language model file $lm2file!\n";
            print STDERR "\nThe language model will be saved in $lm2file";
            print STDERR " in your current directory!\n";
            print STDERR "\nYou need to install it by moving it to \n";
            print STDERR "$LM_HOMEDIR/\n";
        }

        binmode F;
        print F join( "\n", map { "$_\t $$ngram{$_}"; } @sorted ), "\n";
        close F;
        print "LM model successfully created in $lm2file!\n";
    }

    return @sorted;
}


=head1 FUNCTIONS

=head2 C<load_models>

 &load_models
 &load_models ($lm_dir)

=cut

sub load_models {
    my $LMs = shift || $LM_HOMEDIR;
    my $models = shift || \%ngram;

    # open directory to find which languages are supported
    opendir DIR, "$LMs" or die "directory $LMs: $!\n";
    my @languages = sort( grep { s/\.lm// && -r "$LMs/$_.lm" } readdir(DIR) );
    closedir DIR;
    @languages
        or die "sorry, can't read any language models from $LMs\n"
        . "language models must reside in files with .lm ending\n";

    # load model and count for each language.
    my $language;
    my $t1 = new Benchmark;
    foreach $language (@languages) {

        # loads the language model into hash %$language.
        my $rang = 1;
        open( LM, "$LMs/$language.lm" )
            || die "cannot open $language.lm: $!\n";
        binmode(LM);
        while (<LM>) {
            chomp;

            # only use lines starting with appropriate character. Others are
            # ignored.
            if (/^[^$non_word_characters]+/o) {
                $$models{$language}{$&} = $rang++;
            }
        }
        close(LM);
    }
}


=head2 C<lm_exists>

 $result = &lm_exists ($file)

Check if a language model exists for the given file.

=cut

sub lm_exists {
    my $lang = shift;
    my $LMs    = shift || $LM_HOMEDIR;
    my $models = shift || \%ngram;

    # load models if necessary
    load_models() unless ( keys %${models} );
    return 1 if ( exists $$models{$lang} );

    # remove regional variants
    $lang =~ s/\_.*$//;
    return 1 if ( exists $$models{$lang} );
    return 1 if ( exists $$models{ iso639_TwoToThree($lang) } );
    return 0;
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
