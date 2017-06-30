package LetsMT::Import::SRT;

=head1 NAME

LetsMT::Import::SRT - import handler for C<srt> files

=head1 DESCRIPTION

SRT: SubRip Text - a plain-text format for video subtitles.

A child of L<LetsMT::Import::Text|LetsMT::Import::Text>.

=cut

use strict;
use parent 'LetsMT::Import::Text';

use LetsMT::Import;
use LetsMT::Import::Text;
use LetsMT::Import::XCESWriter;
use LetsMT::Lang::ISO639;
use LetsMT::WebService;
use LetsMT::Tools;

use File::ShareDir qw(dist_dir);
use File::Basename;

use Data::Dumper;


=head1 CONSTRUCTOR

=cut

sub new {
    my $class = shift;
    my %self  = @_;
    $self{type} = 'srt';    # we need an srt reader!
    bless \%self, $class;
    return \%self;
}

my $PAUSETHR1 = 1;          # > 1 second --> most probably new sentence
my $PAUSETHR2 = 3;          # > 3 second --> definitely new sentence

# for some languages: always split sentences at new time frames
# (because we know too little about their writing system ....)

my %SPLIT_AT_TIMEFRAME = (
    'heb' => 1,
    'ara' => 1,
    'sin' => 1,
    'tha' => 1,
    'urd' => 1,
    'zho' => 1,
    'chi' => 1,
    'far' => 1,
    'kor' => 1,
    'jpn' => 1
);

our %NONBREAKING = ();
our @opentags    = ();
our @closedtags  = ();


=head1 METHOD

=head2 C<convert>

=cut

sub convert {
    my $self = shift;
    my ( $resource, $importer, $meta_resource ) = @_;

    my $type_pattern = $self->{type_pattern} || $self->{type};
    my $new_resource = $resource->convert_type( $type_pattern, 'xml' );

    # shift the 'uploads' path to local_dir
    $new_resource->shift_path_to_local();

    ## TODO adjust these parameters ....

    my $lang = $resource->language();
    my $prefix_file
        = &dist_dir('LetsMT')
        . '/lang/nonbreaking_prefixes/nonbreaking_prefix.'
        . $lang;
    %NONBREAKING = ();
    read_non_breaking( $prefix_file, \%NONBREAKING );

    my $opt_l = iso639_TwoToThree( $resource->language );
    my $opt_s = 0;

    my $IN = LetsMT::Tools::open_in_file( $resource->local_path )
        || return undef;
    &LetsMT::Tools::mkdir( dirname( $new_resource->local_path() ) );
    my $OUT = LetsMT::Tools::open_out_file( $new_resource->local_path )
        || return undef;

    print_xml_header($OUT);

    my $sid = 1;
    print $OUT "<s id=\"$sid\">\n";
    $sid++;
    my $s_ended = 0;

    # Greek: ';' is a question mark!

    if ( $opt_l eq 'ell' ) {
        my $s_end = "([^\.]\.[\"\']?|[\.\!\?\:\;][\"\']?)";
    }

    my $start   = undef;
    my $end     = undef;
    my $lastend = undef;
    my $id      = undef;
    my $wid     = 0;

    my $newchunk = 0;

    @opentags   = ();
    @closedtags = ();

    my $first = 1;

    while ( my $line = <$IN> ) {
        # remove dos line endings
        $line =~ s/\r\n$/\n/;

        if ( not defined $id ) {
            if ( $line =~ /^\s*([0-9]+)$/ ) {
                $id = $1;
                next;
            }
        }
        elsif ( not defined $start ) {
            if ( $line =~ /^([0-9:,]+) --> ([0-9:,]+)/ ) {
                $start    = $1;
                $end      = $2;
                $newchunk = 1;
                if ($lastend) {
                    if ( time2sec($start) - time2sec($lastend) > $PAUSETHR1 )
                    {
                        if ( not $s_ended ) { $s_ended = 2; }
                        elsif ( $s_ended < 3 ) { $s_ended++; }
                    }
                    if ( time2sec($start) - time2sec($lastend) > $PAUSETHR2 )
                    {
                        $s_ended = 3;
                    }
                }
                next;
            }
        }

        if ( $line =~ /^\s*$/ ) {
            if ($end) {

                # always close all open tags at end of time frame
                closetags($OUT);
                @closedtags = ();    # flush tag-stack ....

                print $OUT "<time id=\"T${id}E\" value=\"$end\" />\n";
                $lastend = $end;
                $id      = undef;
                $start   = undef;
                $end     = undef;
                ## new fragment -> always a possible sentence end!
                if ( not $s_ended ) { $s_ended = 1; }
                ## for some languages: always split here!
                if ( $SPLIT_AT_TIMEFRAME{$opt_l} || $opt_s ) { $s_ended = 3; }
            }
        }
        else {
            # some strange markup in curly brackets in some files
            $line =~ s/\{.*?\}\#?//gs;

            $line = fix_punctuation($line);
            if ( $opt_l eq 'en' || $opt_l eq 'eng' ) {
                $line = fix_eng_ocr_errors($line);
            }

            ## ignore formatting tags!
            my $plain = $line;
            $plain =~ s/\<[^\>]+\>//gs;

            ## if a sentence has been ended before

            if ($s_ended) {

                if ( $s_ended == 3 ) {
                    closetags($OUT);
                    print $OUT "</s>\n";
                    print $OUT "<s id=\"$sid\">\n";
                    reopentags($OUT);
                    $sid++;
                    $wid = 0;
                }

                elsif (
                    $plain =~ /^\s*([\"\'\[]?|[\*\#\']*\s*)[\¿\¡\p{Lu}l]/ )
                {
                    closetags($OUT);
                    print $OUT "</s>\n";
                    print $OUT "<s id=\"$sid\">\n";
                    reopentags($OUT);
                    $sid++;
                    $wid = 0;
                }
                elsif (
                    ( $s_ended == 2 )
                    && ( $plain
                        =~ /^(\s*[\-\#\*\']*\s*[\"\'\[]?[\p{N}\p{Ps}\p{Lu}l])/
                    )
                    )
                {

                    closetags($OUT);
                    print $OUT "</s>\n";
                    print $OUT "<s id=\"$sid\">\n";
                    reopentags($OUT);
                    $sid++;
                    $wid = 0;
                }

                ## new sentence if previous sentence ended with '...'
                ## and this one starts with bullets of quotes
                elsif (( $s_ended == 1 )
                    && ( $plain =~ /^\s*[\-\#\*\'\"]/ ) )
                {
                    closetags($OUT);
                    print $OUT "</s>\n";
                    print $OUT "<s id=\"$sid\">\n";
                    reopentags($OUT);
                    $sid++;
                    $wid = 0;
                }
            }
            if ( $newchunk && $start ) {
                print $OUT "<time id=\"T${id}S\" value=\"$start\" />\n";
            }
            $newchunk = 0;

            ## if there are sentence boundaries within one line:
            ## - add sentence boundaries
            ## - tokenize and print text from previous sentence

            while ( $line =~ /^(.*?[.!?:\]])([^.!?:].*)$/ ) {
                my $before = $1;
                my $after  = $2;

                my $plain_before = $before;
                my $plain_after  = $after;

                $plain_before =~ s/\<[^\>]+\>//gs;
                $plain_after  =~ s/\<[^\>]+\>//gs;

                my $sentence_boundary = 0;
                if ( $plain_before =~ /([^.]\.|[!?:])[\'\"]?\s*$/ ) {
                    if ( $plain_after
                        =~ /^\s+[\-\*\#]*\s*[\¿\¡\"\'\[]?[\p{N}\p{Ps}\p{Lu}]/
                        )
                    {
                        $sentence_boundary = 1;
                    }
                }
                elsif ( $plain_before =~ /([.!?:])[\"\'\]\}\)]?\-?\s*$/ ) {
                    if ( $plain_after =~ /^\s+[\"\']?[\¿\¡\p{Lu}]/ ) {
                        $sentence_boundary = 1;
                    }
                }
                elsif ( $plain_before =~ /\s*\]\s*$/ ) {
                    if ( $plain_after
                        =~ /^\s*[\-\*\#]*\s*[\"\']?[\p{N}\p{Ps}\p{Lu}]/ )
                    {
                        $sentence_boundary = 1;
                    }
                }
                elsif ( $plain_before =~ /^\s*[\-\*\#]*\s*\[.{0,20}\]\s*$/s )
                {
                    $sentence_boundary = 1;
                }

                &print_string( $before, $OUT );

                # check if last token is a non-breaking one
                # --> don't start a new sentence!
                my @tokens = split( /\s+/, $before );
                my $last_token = pop(@tokens);
                $last_token =~ s/\.$//;
                if ( exists $NONBREAKING{$last_token} ) {
                    $sentence_boundary = 0;
                }

                $line = $after;
                if ($sentence_boundary) {
                    closetags($OUT);
                    print $OUT "<\/s>\n<s id=\"$sid\">\n";
                    reopentags($OUT);
                    $sid++;
                    $wid = 0;
                }
            }

            ## background info --> keep separate

            if ( $plain =~ /^\s*[\-\*\#]*\s*\[.{0,20}\]\s*$/ ) {
                $s_ended = 3;
            }

            # sentence-end detected at end-of-string:
            # - either
            #   + non-dot followed by a dot
            #   + one of the following punctuations: [!?:]
            # - possibly followed by quotes or closing brackets ["'\]\}\)]?
            # - followed by 0 or more spaces before end-of-string

            elsif ( $plain =~ /([^.]\.|[!?:])[\'\"]?\s*$/ ) {
                $s_ended = 2;
            }

            ## very weak sentence ending: '...'
            elsif ( $plain =~ /\.\.\.\s*$/ ) {
                $s_ended = 1;
            }

            # possible sentence ending:
            # - one of the punctutation characters [.!?:]
            # - possibly followed by quotes or closing brackets ["'\]\}\)]?
            # - possibly followed by a hyphen
            # - followed by 0 or more spaces before end-of-string
            elsif ( $plain =~ /([.!?:\]])[\"\'\]\}\)]?\-?\s*$/ ) {
                $s_ended = 2;
            }

            else {
                $s_ended = 0;
            }

            &print_string( $line, $OUT );
            my @tokens = split( /\s+/, $line );
            my $last_token = pop(@tokens);

            # check if last token is a non-breaking one
            # --> don't start a new sentence!
            $last_token =~ s/\.$//;
            if ( exists $NONBREAKING{$last_token} ) {
                $s_ended = 0;
            }
        }
    }

    closetags($OUT);
    print $OUT "</s>\n";
    print_xml_footer($OUT);

    close $IN;
    close $OUT;

    return [
        {   resource => $new_resource,
            meta     => {
                size            => $sid,
                'resource-type' => 'corpusfile',
                language        => $lang
            }
        }
    ];
}


=head1 CLASS METHODS

=head2 C<closetags>

=cut

sub closetags {
    my $OUT = shift;
    while ( my $tag = pop(@opentags) ) {
        print $OUT "    </$tag>\n";
        push( @closedtags, $tag );
    }
}


=head2 C<reopentags>

=cut

sub reopentags {
    my $OUT = shift;
    while ( my $tag = pop(@closedtags) ) {
        print $OUT "    <$tag>\n";
        push( @opentags, $tag );
    }
}


=head2 C<_encode>

=cut

sub _encode {
    my $string = shift;
    $string =~ s/&/&amp;/g;
    $string =~ s/</&lt;/g;
    $string =~ s/>/&gt;/g;
    return $string;
}


=head2 C<print_string>

=cut

sub print_string {
    my ( $string, $OUT ) = @_;
    while ( $string =~ s/^(.*?)(\<[^\>]+\>)// ) {
        my ( $text, $t ) = ( $1, $2 );
        print $OUT _encode($text);

        ## it's an opening tag --> store in open-tags
        if ( $t =~ /^\<([^\/]\S*)(\s.*)?\>$/ ) {
            push( @opentags, $1 );
            print $OUT $t;
        }
        ## it's a closing tag --> close open tags if they are not the same
        elsif ( $t =~ /^\<\/(\S+)\>$/ ) {
            my $tagname = $1;
            my $tag     = pop(@opentags);
            while ( $tag && $tagname ne $tag ) {    # while not the same
                print $OUT "</$tag>";               # print closing tag!
                $tag = pop(@opentags);
                if ( not $tag ) {
                    last;
                }    # no more tag open anymore -> bad!
            }
            if ( $tagname ne $tag ) {    # last tag is not the one we need:
                print $OUT "<$tagname>";    # create an opening tag (ugly!)
            }
            print $OUT $t;                  # finally: print closing tag
        }
        else {

            # .... what is this?
        }
    }
    print $OUT _encode($string);
}


=head2 C<print_xml_header>

=cut

sub print_xml_header {
    my $fh = shift;
    print $fh '<?xml version="1.0" encoding="utf-8"?>' . "\n";
    print $fh "<document>\n";
}


=head2 C<print_xml_footer>

=cut

sub print_xml_footer {
    my $fh = shift;
    print $fh "</document>\n";
}


=head2 C<time2sec>

=cut

sub time2sec {
    my $time = shift;
    my ( $h, $m, $s, $ms ) = split( /[^0-9\-]/, $time );
    my $sec = 3600 * $h + 60 * $m + $s + $ms / 1000;
    return $sec;
}


=head2 C<fix_eng_ocr_errors>

In some english subtitle files 'I' is confused with 'l'
in I<I'm> and even for I<It>! (e.g. in C<en/2003/1114-v1.srt.gz>).
This method tries to fix that.

=cut

sub fix_eng_ocr_errors {
    my $line = shift;
    $line
        =~ s/(\A|\s+|[\"\'\[\(\-\#\*])l(t?)(\'[a-z]{1,2}|\s+|,\s+|\.\.\.)/$1I$2$3/gs;

    ## some cases in eng/Comedy/1994/3965_82856_110413_postino_il.xml
    $line =~ s/([^aeiuo])[lI]{3}/$1ill/gs;       # stlll, wlll (too general?)
    $line =~ s/([^AEIOUaeiuo\s])ll/$1il/gs;      # exlled
    $line =~ s/I(ove[d\s])/l$1/gs;               # Ioved
    $line =~ s/llke/like/gs;                     # llke --> like
    $line =~ s/([a-zA-Z])I([^I\sl])/$1l$2/gs;    # onIy, AIfredo
    return $line;
}


=head2 C<fix_punctuation>

=cut

sub fix_punctuation {
    my $line = shift;
    ## replace 2x single quote with double quotes
    $line =~ s/\'\'/\"/g;
    ## found in eng/Comedy/1995/1690_84526_112988_four_rooms.xml.gz:
    ## 2 double quotes ...
    $line =~ s/\"\"+/\"/g;
    return $line;
}


=head2 C<read_non_breaking>

=cut

sub read_non_breaking {
    my $file = shift;
    my $hash = shift;
    if ( -e "$file" ) {
        open( PREFIX, "<:encoding(utf8)", "$file" );
        while (<PREFIX>) {
            my $item = $_;
            chomp($item);
            if ( ($item) && ( substr( $item, 0, 1 ) ne "#" ) ) {
                if ( $item =~ /(.*)[\s]+(\#NUMERIC_ONLY\#)/ ) {
                    $$hash{$1} = 2;
                }
                else {
                    $$hash{$item} = 1;
                }
            }
        }
        close(PREFIX);
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