package LetsMT::DataProcessing::Tokenizer::Europarl;

=head1 NAME

LetsMT::DataProcessing::Tokenizer::Europarl

=head1 IMPLEMENTS

=head2 C<tokenize>

=head2 C<load_prefixes>

=cut

use strict;
use parent 'LetsMT::DataProcessing::Tokenizer::Whitespace';
use File::ShareDir 'dist_dir';
use Log::Log4perl qw(get_logger :levels);

our %NONBREAKING_PREFIX;
our $NONBREAKING_PREFIX_DIR     = &dist_dir('LetsMT') . '/lang/nonbreaking_prefixes';
our $DEFAULT_NONBREAKING_PREFIX = $NONBREAKING_PREFIX_DIR . '/nonbreaking_prefix.en';


sub new {
    my $class = shift;
    my %self  = @_;

    if ( $self{lang} ) {
        load_prefixes( $self{lang}, \%NONBREAKING_PREFIX );
    }

    return bless \%self, $class;
}


sub tokenize {
    my $self = shift;

    my ($text) = @_;
    chomp($text);
    $text = " $text ";

    # seperate out all "other" special characters
    $text =~ s/([^\p{IsAlnum}\s\.\'\`\,\-])/ $1 /g; #`

    #multi-dots stay together
    $text =~ s/\.([\.]+)/ DOTMULTI$1/g;
    while ( $text =~ /DOTMULTI\./ ) {
        $text =~ s/DOTMULTI\.([^\.])/DOTDOTMULTI $1/g;
        $text =~ s/DOTMULTI\./DOTDOTMULTI/g;
    }

    # seperate out "," except if within numbers (5,300)
    $text =~ s/([^\p{IsN}])[,]([^\p{IsN}])/$1 , $2/g;

    # separate , pre and post number
    $text =~ s/([\p{IsN}])[,]([^\p{IsN}])/$1 , $2/g;
    $text =~ s/([^\p{IsN}])[,]([\p{IsN}])/$1 , $2/g;

    # turn `into '
    $text =~ s/\`/\'/g; #`

    #turn '' into "
    $text =~ s/\'\'/ \" /g;

    if ( $$self{lang} eq "en" ) {
        #split contractions right
        $text =~ s/([^\p{IsAlpha}])[']([^\p{IsAlpha}])/$1 ' $2/g;
        $text =~ s/([^\p{IsAlpha}\p{IsN}])[']([\p{IsAlpha}])/$1 ' $2/g;
        $text =~ s/([\p{IsAlpha}])[']([^\p{IsAlpha}])/$1 ' $2/g;
        $text =~ s/([\p{IsAlpha}])[']([\p{IsAlpha}])/$1 '$2/g;

        #special case for "1990's"
        $text =~ s/([\p{IsN}])[']([s])/$1 '$2/g;
    }
    elsif ( ( $$self{lang} eq "fr" ) or ( $$self{lang} eq "it" ) ) {
        #split contractions left
        $text =~ s/([^\p{IsAlpha}])[']([^\p{IsAlpha}])/$1 ' $2/g;
        $text =~ s/([^\p{IsAlpha}])[']([\p{IsAlpha}])/$1 ' $2/g;
        $text =~ s/([\p{IsAlpha}])[']([^\p{IsAlpha}])/$1 ' $2/g;
        $text =~ s/([\p{IsAlpha}])[']([\p{IsAlpha}])/$1' $2/g;
    }
    else {
        $text =~ s/\'/ \' /g;
    }

    #word token method
    my @words = split( /\s/, $text );
    $text = "";
    for ( my $i = 0; $i < ( scalar(@words) ); $i++ ) {
        my $word = $words[$i];
        if ( $word =~ /^(\S+)\.$/ ) {
            my $pre = $1;
            if (( $pre =~ /\./ && $pre =~ /\p{IsAlpha}/ )
                || (   $NONBREAKING_PREFIX{$pre}
                    && $NONBREAKING_PREFIX{$pre} == 1 )
                || ( $i < scalar(@words) - 1
                    && ( $words[ $i + 1 ] =~ /^[\p{IsLower}]/ ) ) )
            {
                #no change
            }
            elsif (
                (      $NONBREAKING_PREFIX{$pre}
                    && $NONBREAKING_PREFIX{$pre} == 2
                )
                && ( $i < scalar(@words) - 1
                    && ( $words[ $i + 1 ] =~ /^[0-9]+/ ) ) )
            {
                #no change
            }
            else {
                $word = $pre . " .";
            }
        }
        $text .= $word . " ";
    }

    # clean up extraneous spaces
    $text =~ s/ +/ /g;
    $text =~ s/^ //g;
    $text =~ s/ $//g;

    #restore multi-dots
    while ( $text =~ /DOTDOTMULTI/ ) {
        $text =~ s/DOTDOTMULTI/DOTMULTI./g;
    }
    $text =~ s/DOTMULTI/./g;

    #ensure final line break
    $text .= "\n" unless $text =~ /\n$/;
    # return split( /\s+/, $text );
    return wantarray ? split( /\s+/, $text ) : join( ' ', split( /\s+/, $text ) );
}


sub load_prefixes {
    my ( $language, $PREFIX_REF ) = @_;

    my $prefixfile
        = $NONBREAKING_PREFIX_DIR . '/nonbreaking_prefix.' . $language;

    #default back to English if we don't have a language-specific prefix file
    if ( !( -e $prefixfile ) ) {
        $prefixfile = $DEFAULT_NONBREAKING_PREFIX;
        get_logger(__PACKAGE__)->warn(
            "WARNING: No known abbreviations for language '$language', attempting fall-back to English version..."
        );
        unless ( -e $prefixfile ) {
            get_logger(__PACKAGE__)->warn("falling back to English");
            return 0;
        }
    }

    if ( -e "$prefixfile" ) {
        open( PREFIX, "<:encoding(utf8)", "$prefixfile" );
        while (<PREFIX>) {
            my $item = $_;
            chomp($item);
            if ( ($item) && ( substr( $item, 0, 1 ) ne "#" ) ) {
                if ( $item =~ /(.*)[\s]+(\#NUMERIC_ONLY\#)/ ) {
                    $PREFIX_REF->{$1} = 2;
                }
                else {
                    $PREFIX_REF->{$item} = 1;
                }
            }
        }
        close(PREFIX);
    }
}


# this is the Moses detokenizer
# written by Josh Schroeder, based on code by Philipp Koehn

sub detokenize {
    my $self  = shift;
    my $token = shift;

    my $text = ref($token) eq 'ARRAY' ? join( ' ', @$token ) : $token;
    my $language = $self->{-lang} || 'en';

    #    chomp($text);
    $text =~ s/\n/ /gs;
    $text =~ s/\s\s+/ /gs;
    $text = " $text ";

    my $word;
    my $i;
    my @words = split( / /, $text );
    $text = "";
    my %quoteCount = ( "\'" => 0, "\"" => 0 );
    my $prependSpace = " ";
    for ( $i = 0; $i < ( scalar(@words) ); $i++ ) {
        if ( $words[$i] =~ /^[\p{IsSc}\(\[\{\¿\¡]+$/ ) {
            # perform right shift on currency and other random punctuation items
            $text         = $text . $prependSpace . $words[$i];
            $prependSpace = "";
        }
        elsif ( $words[$i] =~ /^[\,\.\?\!\:\;\\\%\}\]\)]+$/ ) {
            # perform left shift on punctuation items
            $text         = $text . $words[$i];
            $prependSpace = " ";
        }
        elsif (( $language eq "en" )
            && ( $i > 0 )
            && ( $words[$i] =~ /^[\'][\p{IsAlpha}]/ )
            && ( $words[ $i - 1 ] =~ /[\p{IsAlnum}]$/ ) )
        {
            # left-shift the contraction for English
            $text         = $text . $words[$i];
            $prependSpace = " ";
        }
        elsif (( $language eq "fr" )
            && ( $i < ( scalar(@words) - 2 ) )
            && ( $words[$i] =~ /[\p{IsAlpha}][\']$/ )
            && ( $words[ $i + 1 ] =~ /^[\p{IsAlpha}]/ ) )
        {
            # right-shift the contraction for French
            $text         = $text . $prependSpace . $words[$i];
            $prependSpace = "";
        }
        elsif ( $words[$i] =~ /^[\'\"]+$/ ) {
            # combine punctuation smartly
            if ( ( $quoteCount{ $words[$i] } % 2 ) eq 0 ) {
                if (   ( $language eq "en" )
                    && ( $words[$i] eq "'" )
                    && ( $i > 0 )
                    && ( $words[ $i - 1 ] =~ /[s]$/ ) )
                {
                   # single quote for posesssives ending in s... "The Jones' house"
                   # left shift
                    $text         = $text . $words[$i];
                    $prependSpace = " ";
                }
                else {
                    # right shift
                    $text         = $text . $prependSpace . $words[$i];
                    $prependSpace = "";
                    $quoteCount{ $words[$i] } = $quoteCount{ $words[$i] } + 1;
                }
            }
            else {
                # left shift
                $text                     = $text . $words[$i];
                $prependSpace             = " ";
                $quoteCount{ $words[$i] } = $quoteCount{ $words[$i] } + 1;
            }
        }
        else {
            $text         = $text . $prependSpace . $words[$i];
            $prependSpace = " ";
        }
    }

    # clean up spaces at head and tail of each line as well as any double-spacing
    $text =~ s/ +/ /g;
    $text =~ s/\n /\n/g;
    $text =~ s/ \n/\n/g;
    $text =~ s/^ //g;
    $text =~ s/ $//g;

    # add trailing break
    #$text .= "\n" unless $text =~ /\n$/;

    return $text;
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
