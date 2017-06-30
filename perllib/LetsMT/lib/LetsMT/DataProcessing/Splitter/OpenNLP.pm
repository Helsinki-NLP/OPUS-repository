package LetsMT::DataProcessing::Splitter::OpenNLP;

=head1 NAME

LetsMT::DataProcessing::Splitter::OpenNLP - OpenNLP sentence splitter

=head1 SYNOPSIS

 use LetsMT::DataProcessing::Splitter::OpenNLP;
 my $splitter = LetsMT::DataProcessing::Splitter::OpenNLP->new (lang => 'en');
 my $text = 'This is a paragraph. It contains several sentences. "But why," you ask?';
 print $splitter->split($text);

=head1 DESCRIPTION

This module allows splitting of text paragraphs into sentences.
It uses the Apache Foundation's OpenNLP tool (L<http://opennlp.apache.org/>).

The module uses trainable models to split paragraphs
into an newline-separated string with one sentence per line.
For example:

 This is a paragraph. It contains several sentences. "But why," you ask?

goes to:

 This is a paragraph.
 It contains several sentences.
 "But why," you ask?


=head2 Training

--TODO--

=cut

use 5.008008;

use strict;
use parent 'LetsMT::DataProcessing::Splitter';

use File::ShareDir 'dist_dir';
use Log::Log4perl qw(get_logger :levels);

# defaults: language = English
our $DEFAULT_LANG  = 'en';

our $MODELS_DIR    = &dist_dir('LetsMT') . '/lang/opennlp';
our $DEFAULT_MODEL = "$MODELS_DIR/$DEFAULT_LANG-sent.bin";


#------------------------------------------------------------
# put all opennlp jar-files in the class path
#------------------------------------------------------------

BEGIN {
    my $libdir='/usr/local/lib';
    my @jars=();
    opendir LIBDIR,$libdir or die $1; 
    while( my $fname = readdir(LIBDIR)){
        next unless $fname =~/^opennlp.*\.jar$/;
        push(@jars,$libdir . "/" . $fname);
    }
    $ENV{CLASSPATH}=join(":",@jars);

}

#------------------------------------------------------------
# use inline java code to call the sentence splitter
#------------------------------------------------------------

# use Inline Java => << 'END_OF_JAVA_CODE' => CLASSPATH => $ENV{CLASSPATH};
use Inline Java => << 'END_OF_JAVA_CODE' => CLASSPATH => '/usr/local/lib/opennlp-tools-1.5.2-incubating.jar:/usr/local/lib/opennlp-maxent-3.0.2-incubating.jar', EXTRA_JAVA_ARGS => '-Xmx1024m';

import java.io.*;
import opennlp.tools.sentdetect.*;

class SentenceSplitter {
    SentenceDetectorME sentenceDetector;
    public SentenceSplitter(String file){
	try {
	    InputStream modelIn = new FileInputStream(file);
	    SentenceModel model = new SentenceModel(modelIn);
	    sentenceDetector = new SentenceDetectorME(model);
	} catch (IOException e) {
	    e.printStackTrace();
	}
    }
    public String[] split(String sentence){
	return sentenceDetector.sentDetect(sentence);
    }
}
END_OF_JAVA_CODE




=head1 CONSTRUCTOR

 LetsMT::DataProcessing::Splitter::OpenNLP->new (%OPTIONS)

OPTIONS:

 lang ... Language code (default/fallback: en)

=cut

sub new {
    my $class = shift;

    Inline->init();

    my $self = {};
    %{$self} = @_;

    $self->{lang}  ||= $DEFAULT_LANG;
    if ( $self->{lang} !~ /^[a-z][a-z]$/ ) {
        get_logger(__PACKAGE__)->warn("Invalid language id: $self->{lang}");
        $self->{lang} = $DEFAULT_LANG;
    }

    unless ( defined($self->{model}) && ( -e $self->{model}) ) {
        get_logger(__PACKAGE__)->warn(
            "WARNING: Specified model file '$self->{model}' does not exist, attempting fall-back to $self->{lang} version..."
        );
        $self->{model} = "$MODELS_DIR/$self->{lang}-sent.bin";
    }

    # create the splitter instance and load the model
    $self->{splitter} = 
	new LetsMT::DataProcessing::Splitter::OpenNLP::SentenceSplitter(
	    $self->{model}) ;

    get_logger(__PACKAGE__)->warn("use OpenNLP with $self->{model}");


    bless $self, $class;
    return $self;
}

=head1 METHODS

=head2 C<split>

=cut

sub split {
    my $self = shift;
    my $str;

    ## keep separate lines: do not merge with space!
    ## --> no sentences beyond line breaks!
    if ( $self->{separate_lines} ) {
        $str = join( "\n", @_ );
        $str =~ s/^\s*//s;
    }
    else {
        ## add newlines to empty lines to force sentence breaks between strings
        map( s/^(\s*)\n?$/$1\n/, @_ );

        # (but remove leading blanks to avoid empty sentences ....)
        $str = join( ' ', @_ );
        $str =~ s/^\s*//s;
    }

    my $sents = $self->{splitter}->split($str);
    return @{$sents};
}


=head2 C<train>

=cut

sub train {
    my $self = shift;

    my $lang        = shift;
    my $sample_text = shift;
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
