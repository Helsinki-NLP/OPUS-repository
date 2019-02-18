# -*-perl-*-

package LetsMT::Lang::Encoding;

=head1 NAME

LetsMT::Lang::Encoding

=cut

use strict;

use Exporter 'import';
our @EXPORT = qw( detect_encoding text2utf8 text2utf8_inplace );
our %EXPORT_TAGS = ( all => \@EXPORT );

use LetsMT::Lang::ISO639 qw / :all /;
use LetsMT::Lang::Detect;
use LetsMT::Tools qw / :all /;

use PerlIO::encoding;
$PerlIO::encoding::fallback = Encode::FB_QUIET;
# $PerlIO::encoding::fallback = Encode::FB_DEFAULT;

use File::Temp 'tempfile';
use File::Copy;
use File::LibMagic;
use FindBin qw($Bin);
use Encode;
use File::BOM qw( :all );
use File::GetLineMaxLength;

use File::ShareDir 'dist_dir';
our $LOCAL_MODELS = &dist_dir('LetsMT') . '/lang/chared';

## don't use textcat for encoding detection!
# our $TEXTCAT_LM_DIR = &dist_dir('LetsMT') . '/lang/textcat2';


## create LibMagic handle
## TODO: this does not seem to work in mod_perl
## check File::Type? (does not give encoding)
## alternative: File::Type::FFI (https://metacpan.org/pod/File::LibMagic::FFI)
##
# my $LIBMAGIC = File::LibMagic->new();


# my %TEXTCAT_MODELS = ();

# initialize list of chared models (if chared is found)

our $CHARED        = undef;
our $CHARED_LEARN  = undef;
our %CHARED_MODELS = ();

our $SIZE_CHARED     = 2**16;  # text size used for detection (in bytes)
our $MAX_LINE_LENGTH = 2**16;  # max line length when reading files


sub initialize_chared{

    unless ($CHARED){
	$CHARED       = `which chared`       || undef;
	$CHARED_LEARN = `which chared-learn` || undef;
    }

    if ($CHARED) {
	chomp($CHARED);
	my $models = `$CHARED --list-models`;
	foreach ( split( /\s/, $models ) ) {
	    my $id = &iso639_NameToTwo($_);
	    $CHARED_MODELS{$id} = $_;
	}
    }
}


=head1 FUNCTIONS

=head2 C<create_model>

=cut

sub create_model {
    my $lang        = shift;
    my $sample_text = shift;
    my @html_files  = @_;

    die "cannot find chared-learn" unless ($CHARED_LEARN);

    ### make the model file

    my $id2     = &iso639_AnyToTwo($lang);
    my $id3     = &iso639_TwoToThree($id2);
    my $lm2file = $LOCAL_MODELS . '/' . $id2 . '.edm';
    my $lm3file = $LOCAL_MODELS . '/' . $id3 . '.edm';
    if ( -e $lm2file || -e $lm3file ) {
        print STDERR "\nLM for '$lang' exists ($lm2file)!\n";
        $lm2file = $id2 . '.edm';
        die "\nLocal LM file exists ($lm2file)!\n" if ( -e $lm2file );
        print STDERR "\nThe language model will be saved in $lm2file";
        print STDERR " in your current directory!\n";
        print STDERR "\nYou need to install it by moving it to \n";
        print STDERR "$LOCAL_MODELS/\n";
    }

    # call chared-learn

    my $safesample = &safe_path($sample_text);
    my $input      = join( ' ', map ( $_ = &safe_path($_), @html_files ) );
    my $result     = `$CHARED_LEARN -o $lm2file -S $safesample $input`;

    # should check output here ....

    #    print "LM model successfully created in $lm2file!\n";
}


=head2 C<text2utf8>

 $outfile = &text2utf8 ($infile, $outfile, $enc, $lang)

Convert a text to uft-8 encoding.

Returns the name of the output file on success,
or C<undef> on failure.

=cut

# text2utf8( $infile, $outfile, $enc, $lang )
#
# convert a text to utf-8
#
# infile .... input text
# outfile ... output text
# enc ....... input char encoding (optional), try to detect if not given
# lang ...... source language of input text (needed for automatic detection)

sub text2utf8 {
    my $infile  = shift;
    my $outfile = shift;
    my $enc     = shift;
    my $lang    = shift;

    $enc = $enc || &detect_encoding( $infile, $lang );

    # open input file (may be compresses)

    my $in     = &open_bom_file( $infile, $enc );
    my $reader = File::GetLineMaxLength->new($in);

    my $input;
    my $out;

    # write to output file
    if   ( $outfile =~ /\.gz/ ) {
	my $safepath = quotemeta($outfile);
        open $out, "| gzip -c > $safepath";
    }
    else {
        open $out, '>', $outfile;
    }

    binmode( $out, ":encoding(utf8)" );

    do {
        eval { print $out $input; };
        if ($@) { print STDERR $@; return undef; }
        # eval { $input = &fgets( $in, $MAX_LINE_LENGTH ); };
        eval { $input = $reader->getline( $MAX_LINE_LENGTH ); };
        if ($@) { print STDERR $@; return undef; }
    } while ( $input );

    close $in;
    close $out;

    return $outfile;
}


=head2 C<text2utf8>

 $status = &text2utf8 ($infile, $enc, $lang)

Convert a text to uft-8 encoding in place.

=cut

sub text2utf8_inplace {
    my $infile = shift;
    my $enc    = shift;
    my $lang   = shift;

    $enc = $enc || &detect_encoding( $infile, $lang );

    # it's already in utf-8! nothing more I can do ....
    return 1 if ( $enc eq 'utf-8' );

    # otherwise: open a temp file and convert
    my ( $fh, $outfile ) = tempfile();
    close $fh;
    &text2utf8( $infile, $outfile, $enc, $lang ) || return 0;

    # the critical part: overwrite the original file!
    # gzipped --> should compress again (but use the fast algorithm)
    if ( $infile =~ /\.gz/ ) {
        my $safein  = quotemeta($infile);
        my $safeout = quotemeta($outfile);
        system("gzip -1c $safeout > $safein");
    } else {
        # move otherwise
        move( $outfile, $infile );
    }
    return 1;
}


=head2 C<detect_encoding>

 $encoding = &detect_encoding ($file, $lang)

Try to detect the character encoding (mainly using chared).

=cut

sub detect_encoding {

    my $file = shift;
    my $lang = shift;

    # 1) try with BOM first
    if (open( my $fh, "<:bytes", $file )){
        if (my $encoding = &File::BOM::get_encoding_from_filehandle($fh)){
            close($fh);
            return $encoding;
        }
        close($fh);
    }

    # 2) try with chared
    # generate a warning if chared is not installed!

    if ($lang){
	# use traditional Chinese as standard for chinese
	if ( $lang eq 'zh' ) {
	    $lang = 'zh_TW';
	}

	&initialize_chared();
	unless ($CHARED){
	    get_logger(__PACKAGE__)->warn("chared is not found!");
	}

	# try without regional variation
	if ( !exists $CHARED_MODELS{$lang} ) {
	    my $langID = $lang;    # langID is without regional variation
	    $langID =~ s/\_.*$//;
	    $lang = $langID if ( exists $CHARED_MODELS{$langID} );

	    # check if we have our own detection model
	    if ( !exists $CHARED_MODELS{$lang} ) {
		if ( -e "$LOCAL_MODELS/$lang.edm" ) {
		    $CHARED_MODELS{$lang} = "$LOCAL_MODELS/$lang.edm";
		}
	    }
	}

	# use the encoding detector of croatian
	# for serbo-croation
	$lang = 'hr' if ( $lang eq 'scc' || $lang eq 'scc' );

	my ( $CharedModels, $CharedCmd );

	if ( exists $CHARED_MODELS{$lang} ) {

	    my $in;
	    if ( $file =~ /\.gz/ ) { open $in, "gzip -cd < $file |"; }
	    else                   { open $in, "< $file"; }
	    my ( $out, $filename ) = tempfile();

	    binmode($in);
	    binmode($out);

	    my $input;
	    read( $in, $input, $SIZE_CHARED );
	    print $out $input;

	    close $in;
	    close $out;

	    # call chared to predict the encoding
	    my ($success,$ret,$result,$err) =
		&run_cmd( $CHARED, '-m', $CHARED_MODELS{$lang},$filename );

	    if ($success) {
		chomp($result);
		my ( $path, $guess ) = split( /\t/, $result );

		# unify encoding names
		$guess = 'iso-8859-1' if ( $guess eq 'latin_1' );
		$guess =~ s/iso8859_/iso-8859-/;
		$guess =~ s/utf_8/utf-8/;
		$guess =~ s/koi8_/koi8-/;
		$guess =~ s/big5/big5-eten/;

		unlink $filename unless ( $filename eq $file );
		return $guess;
	    }
	}

	# 3) use some other ways to guess the encoding
	else {
	    $lang = iso639_TwoToThree($lang);
	    return guess_encoding( $lang, $file );
	}
    }

    ## 3) try LibMagic
    ##    TODO: should that before using chared?
    ##    TODO: creating new objects is not very efficient
    ##          but creating a global handle at the start of the module
    ##          does not work with mod_perl it seems
    ##    TODO: sometimes it croaks on empty files
    ##          (error calling magic_file: (null))
    ##          --> enclose in eval to avoid breaking out
    my $LIBMAGIC = File::LibMagic->new();
    my $info = undef;
    eval { $info = $LIBMAGIC->info_from_filename($file); };
    if (ref($info) eq 'HASH'){
    	if (defined $info->{encoding}){
    	    return $info->{encoding} unless ($info->{encoding} eq 'binary' ||
    					     $info->{encoding}=~/unknown/);
    	}
    }

    # OLD: call file command
    #
    # ##    TODO: file causes some memory problems when forking
    # ##          (does this system call work better?)
    # # my ($success,$ret,$out,$err) = &run_cmd( 'file', '-i', $file );
    # my ($out) = &LetsMT::Tools::scrape_cmd_out( 'file', '-i', $file );
    # # if ($success) {
    # 	if ($out=~/charset=(\S+)(\s|\Z)/){
    # 	    my $enc = $1;
    # 	    return $enc unless ($enc eq 'binary' || $enc=~/unknown/);
    # 	}
    # # }


    ## TODO: disable this now because we took away classify_with_textcat
    ## ---> check if we need something here

    # # last chance: try the hard way and do language + encoding detection
    # my ($lang) = &LetsMT::Lang::Detect::classify_with_textcat($file,$TEXTCAT_LM_DIR,
    # 							      \%TEXTCAT_MODELS);
    # if ($lang=~/^(.*)\.(.*)$/){
    # 	return $2;
    # }

    return 'utf-8';
}


=head2 C<guess_encoding>

 $encoding = &guess_encoding ($lang, $file)

Heuristics for setting character encoding depending on the source language
(this assumes that most stuff comes from the windows world ...).

Requires 'file' tool!

=cut

sub guess_encoding {
    my ( $lang, $file ) = @_;

    # ## use LibMagic to determine character encoding
    ##    TODO: creating new objects is not very efficient
    ##          but cteating a global handle at the start of the module
    ##          does not work with mod_perl it seems
    my $LIBMAGIC = File::LibMagic->new();
    my $info = undef;
    eval { $info = $LIBMAGIC->info_from_filename($file); };
    if (ref($info) eq 'HASH'){
    	if (defined $info->{encoding}){
    	    return $info->{encoding} unless ($info->{encoding} eq 'binary' ||
    					     $info->{encoding}=~/unknown/);
	}
    }


    ## TODO: check (and remove) this strange code below ... 

    ## supported by Perl Encode:
    ## use Encode; @all_encodings = Encode->encodings(":all");

    return 'iso-8859-4' if ( $lang =~ /^(ice)$/ );
    ## what is scc? serbo-croatian? same as scr?
    return 'cp1250'
        if (
        $lang =~ /^(alb|bos|cze|pol|rum|scc|scr|slv|slo|slk|sqi|hrv|hun)$/ );

    # return 'iso-8859-2' if ($lang=~/^(alb|bos)$/);
    return 'cp1251' if ( $lang =~ /^(bul|mac|rus|bel|ukr)$/ );

    # return 'cp1252' if ($lang=~/^(dan|dut|epo|est|fin|fre|ger|ita|nor|pob|pol|por|spa|swe)$/);
    return 'cp1253'    if ( $lang =~ /^(ell|gre)$/ );
    return 'cp1254'    if ( $lang =~ /^(tur)$/ );
    return 'cp1255'    if ( $lang =~ /^(heb)$/ );
    return 'cp1256'    if ( $lang =~ /^(ara)$/ );
    return 'cp1257'    if ( $lang =~ /^(lat|lit)$/ );    # correct?
    return 'big5-eten' if ( $lang =~ /^(chi|zho)$/ );

    # Georgian --> use recode to convert it to utf-8
    if ( $lang eq 'geo' ) {
        if ( $file =~ /\.gz$/ ) {
            my $filetype = `gzip -cd $file | file -`;
            if ( $filetype !~ /UTF-8/ ) {
                system("zcat $file | recode -f Georgian-PS..utf8 | gzip -c > $file.tmp");
                system("mv $file $file.bak");
                system("mv $file.tmp $file");
            }
        }
        else {
            my $filetype = `file $file`;
            if ( $filetype !~ /UTF-8/ ) {
                system("recode -f Georgian-PS..utf8 < $file > $file.tmp");
                system("mv $file $file.bak");
                system("mv $file.tmp $file");
            }
        }
        return 'utf-8';
    }

    ## Thai --> use recode to convert it into utf-8
    if ( $lang eq 'tha' ) {
        if ( $file =~ /\.gz$/ ) {
            my $filetype = `gzip -cd $file | file -`;
            if ( $filetype !~ /UTF-8/ ) {
                system(
                    "zcat $file | recode -f TIS620..utf8 | gzip -c > $file.tmp"
                );
                system("mv $file $file.bak");
                system("mv $file.tmp $file");
            }
        }
        else {
            my $filetype = `file $file`;
            if ( $filetype !~ /UTF-8/ ) {
                system("recode -f TIS620..utf8 < $file > $file.tmp");
                system("mv $file $file.bak");
                system("mv $file.tmp $file");
            }
        }
        return 'utf-8';
    }

    ## Korean: check with 'file'
    if ( $lang eq 'kor' ) {
        my $filetype = '';
        if ( $file =~ /\.gz$/ ) {
            $filetype = `gzip -cd $file | file -`;
        }
        else {
            $filetype = `file $file`;
        }
        return 'utf-8' if ( $filetype =~ /UTF-8/ );
        return 'euc-kr';
    }

    ## Japanese: use 'file' to check whether it is utf-8 or not
    if ( $lang eq 'jpn' ) {
        my $filetype = '';
        if ( $file =~ /\.gz$/ ) {
            $filetype = `gzip -cd $file | file -`;
        }
        else {
            $filetype = `file $file`;
        }
        return 'utf-8' if ( $filetype =~ /UTF-8/ );
        return 'shiftjis';

        # return 'cp932' if ($lang=~/^(jpn)$/);
    }

    return 'euc-kr' if ( $lang =~ /^(kor)$/ );

    # return 'cp949' if ($lang=~/^(kor)$/);
    # return 'utf-8' if ( $lang =~ /^(per|hin|kaz|sin|urd|vie)$/ );

    # return 'cp1252';
    # return 'iso-8859-6' if ($lang=~/^(ara)$/);
    # return 'iso-8859-7' if ($lang=~/^(ell|gre)$/);
    # return 'iso-8859-1';

    # utf-8 is default ....
    return 'utf-8';

    ## unknown: haw (hawaiian), hrv (crotioan), amh (amharic) gai (borei)
    ##          ind (indonesian), max (North Moluccan Malay), may (Malay?)
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
