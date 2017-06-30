package LetsMT::DataProcessing::Splitter::Europarl;

# sentence splitter based on the Moses/Europarl sentence splitter
# (adjusted from Lingua::Sentence to LetsMT)

=head1 NAME

LetsMT::DataProcessing::Splitter::Europarl - Moses/Europarl sentence splitter

=head1 SYNOPSIS

 use LetsMT::DataProcessing::Splitter::Europarl;
 my $splitter = LetsMT::DataProcessing::Splitter::Europarl->new (lang => 'en');
 my $text = 'This is a paragraph. It contains several sentences. "But why," you ask?';
 print $splitter->split($text);

=head1 DESCRIPTION

This module allows splitting of text paragraphs into sentences.
It is based on scripts developed by Philipp Koehn and Josh Schroeder
for processing the Europarl corpus (L<http://www.statmt.org/europarl/>).

The module uses punctuation and capitalization clues to split paragraphs
into an newline-separated string with one sentence per line.
For example:

 This is a paragraph. It contains several sentences. "But why," you ask?

goes to:

 This is a paragraph.
 It contains several sentences.
 "But why," you ask?

Languages currently supported by the module are:

=over

=item Catalan

=item Dutch

=item English

=item French

=item German

=item Greek

=item Italian

=item Portuguese

=item Spanish

=back


=head2 Nonbreaking-Prefixes Files

Nonbreaking prefixes are loosely defined as any word ending in a period
that does NOT indicate an end of sentence marker.
A basic example is Mr. and Ms. in English.

The sentence splitter module uses the nonbreaking prefix files included in this distribution.

To add a file for other languages, follow the naming convention nonbreaking_prefix.??
and use the two-letter language code you intend to use when creating a Lingua::Sentence object.

The sentence splitter module will first look for a file for the language it is processing,
and fall back to English if a file for that language is not found. 

For the splitter, normally a period followed by an uppercase word results in a sentence split.
If the word preceeding the period is a nonbreaking prefix, this line break is not inserted.

A special case of prefixes, NUMERIC_ONLY, is included for special cases where the prefix should be handled ONLY when before numbers.
For example, "Article No. 24 states this." the No. is a nonbreaking prefix.
However, in "No. It is not true." No functions as a word.

See the example prefix files included in the distribution for more examples.

=cut

use strict;
use parent 'LetsMT::DataProcessing::Splitter';

use LetsMT::DataProcessing::Splitter;
use File::ShareDir 'dist_dir';
use Log::Log4perl qw(get_logger :levels);

# defaults: language = English

our $DEFAULT_LANG = 'en';

our $NONBREAKING_PREFIX_DIR     = &dist_dir('LetsMT') . '/lang/nonbreaking_prefixes';
our $DEFAULT_NONBREAKING_PREFIX = $NONBREAKING_PREFIX_DIR . '/nonbreaking_prefix.' . $DEFAULT_LANG;


=head1 CONSTRUCTOR

The constructor can be called in two ways:

 LetsMT::DataProcessing::Splitter::Europarl->new (lang => $lang_id)

Instantiate an object to split sentences in language C<$lang_id>.
If the language is not supported, a splitter object for English will be instantiated.

=cut

sub new {
    my $class = shift;

    my $self = {};
    %{$self} = @_;

    $self->{lang} = $DEFAULT_LANG unless ( defined $self->{lang} );
    bless $self, $class;
    $self->init( $self->{lang} );
    return $self;
}


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

    ## split the joined text string
    return $self->split_array($str);

    # old version: no pre-processing ---> leads to long sentences ...
    #    return $self->split_array( join( ' ', @_ ) );
}


# Preloaded methods go here.

# TODO: should we integrate the init functionality in the constructor?
#       (prefixfile as argument to the constructor)

sub init {
    my $self = shift;

    my $langid = shift;
    if ( $langid !~ /^[a-z][a-z]$/ ) {
        get_logger(__PACKAGE__)->warn("Invalid language id: $langid");
    }
    my $prefixfile = shift;

    # Try loading nonbreaking prefix file specified in constructor
    my $dir = dist_dir('LetsMT') . '';
    if ( defined($prefixfile) ) {
        if ( !( -e $prefixfile ) ) {
            get_logger(__PACKAGE__)->warn(
                "WARNING: Specified prefix file '$prefixfile' does not exist, attempting fall-back to $langid version..."
            );
            $prefixfile = "$dir/nonbreaking_prefix.$langid";
        }
    }
    else {
        $prefixfile = "$NONBREAKING_PREFIX_DIR/nonbreaking_prefix.$langid";
    }

    my %NONBREAKING_PREFIX;

    #default back to English if we don't have a language-specific prefix file
    if ( !( -e $prefixfile ) ) {
        $prefixfile = $DEFAULT_NONBREAKING_PREFIX;
        get_logger(__PACKAGE__)->warn(
            "WARNING: No known abbreviations for language '$langid', attempting fall-back to English version..."
        );
        unless ( -e $prefixfile ) {
            get_logger(__PACKAGE__)->err(
                "ERROR: No abbreviations files found in $dir"
            );
            die "ERROR: No abbreviations files found in $dir";
        }
    }
    if ( -e "$prefixfile" ) {
        open( PREFIX, "<:encoding(utf8)", "$prefixfile" );
        while (<PREFIX>) {
            my $item = $_;
            chomp($item);
            if ( ($item) && ( substr( $item, 0, 1 ) ne "#" ) ) {
                if ( $item =~ /(.*)[\s]+(\#NUMERIC_ONLY\#)/ ) {
                    $NONBREAKING_PREFIX{$1} = 2;
                }
                else {
                    $NONBREAKING_PREFIX{$item} = 1;
                }
            }
        }
        close(PREFIX);
    }

    $self->{LangID}      = $langid;
    $self->{Nonbreaking} = \%NONBREAKING_PREFIX;
    return $self;
}


sub split_array {
    my $self = shift;
    if ( !ref $self ) {
        return "Unnamed $self";
    }
    my $text = shift;
    if ( !$text ) {
        return ();
    }
    my $splittext = _preprocess( $self, $text );
    chomp $splittext;
    return split( /\n/, $splittext );
}


sub _preprocess {
    my ( $self, $text ) = @_;

    # clean up spaces at head and tail of each line as well as any double-spacing
    $text =~ s/ +/ /g;
    $text =~ s/\n /\n/g;
    $text =~ s/ \n/\n/g;
    $text =~ s/^ //g;
    $text =~ s/ $//g;

    ##### add sentence breaks as needed #####

    #non-period end of sentence markers (?!) followed by sentence starters.
    $text =~ s/([?!]) +([\'\"\(\[\¿\¡\p{IsPi}\x{201E}]*[\p{IsUpper}])/$1\n$2/g;

    #multi-dots followed by sentence starters
    $text =~ s/(\.[\.]+) +([\'\"\(\[\¿\¡\p{IsPi}\x{201E}]*[\p{IsUpper}])/$1\n$2/g;

    # add breaks for sentences that end with some sort of punctuation
    # inside a quote or parenthetical and are followed by a possible
    # sentence starter punctuation and upper case
    $text =~ s/([?!\.][\ ]*[\'\"\)\]\p{IsPf}]+) +([\'\"\(\[\¿\¡\p{IsPi}\x{201E}]*[\ ]*[\p{IsUpper}])/$1\n$2/g;

    # add breaks for sentences that end with some sort of punctuation are
    # followed by a sentence starter punctuation and upper case
    $text =~ s/([?!\.]) +([\'\"\(\[\¿\¡\p{IsPi}\x{201E}]+[\ ]*[\p{IsUpper}])/$1\n$2/g;

    # special punctuation cases are covered. Check all remaining periods.
    my $word;
    my $i;
    my @words = split( / /, $text );
    $text = "";
    for ( $i = 0; $i < ( scalar(@words) - 1 ); $i++ ) {
        if ( $words[$i]
            =~ /([\p{IsAlnum}\.\-]*)([\'\"\)\]\%\p{IsPf}]*)(\.+)$/ )
        {
            #check if $1 is a known honorific and $2 is empty, never break
            my $prefix         = $1;
            my $starting_punct = $2;
            if (   $prefix
                && $self->{Nonbreaking}{$prefix}
                && $self->{Nonbreaking}{$prefix} == 1
                && !$starting_punct )
            {
                #not breaking;
            }
            elsif ( $words[$i] =~ /(\.)[\p{IsUpper}\-]+(\.+)$/ ) {
                #not breaking - upper case acronym
            }
            elsif ( $words[ $i + 1 ] =~ /^([ ]*[\'\"\(\[\¿\¡\p{IsPi}\x{201E}]*[ ]*[\p{IsUpper}0-9])/ ) {
                # the next word has a bunch of initial quotes,
                # maybe a space, then either upper case or a number
                $words[$i] = $words[$i] . "\n"
                    unless ( $prefix
                    && $self->{Nonbreaking}{$prefix}
                    && $self->{Nonbreaking}{$prefix} == 2
                    && !$starting_punct
                    && ( $words[ $i + 1 ] =~ /^[0-9]+/ ) );
                # we always add a return for these unless we have
                # a numeric non-breaker and a number start
            }

        }
        $text = $text . $words[$i] . " ";
    }

    # we stopped one token from the end to allow for easy look-ahead. Append it now.
    $text = $text . $words[$i];

    # clean up spaces at head and tail of each line as well as any double-spacing
    $text =~ s/ +/ /g;
    $text =~ s/\n /\n/g;
    $text =~ s/ \n/\n/g;
    $text =~ s/^ //g;
    $text =~ s/ $//g;

    #add trailing break
    $text .= "\n" unless $text =~ /\n$/;

    return $text;
}


1;

=head2 CREDITS

Thanks for the following individuals for supplying nonbreaking prefix files:
Bas Rozema (Dutch), HilE<aacute>rio Leal Fontes (Portuguese), JesE<uacute>s GimE<eacute>nez (Catalan & Spanish)

=head1 SUPPORT

Bugs should always be submitted via the project hosting bug tracker

L<http://code.google.com/p/corpus-tools/issues/list>

For other issues, contact the maintainer.

=head1 SEE ALSO

L<Text::Sentence>,
L<Lingua::EN::Sentence>,
L<Lingua::DE::Sentence>,
L<Lingua::HE::Sentence>

=head1 AUTHOR

Lingua::Sentence: Achim Ruopp, E<lt>achimru@gmail.comE<gt>
Adjusted for LetsMT: Joerg Tiedemann

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Digital Silk Road

Portions Copyright (C) 2005 by Philip Koehn and Josh Schroeder (used with permission)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


AS PART OF LetsMT! Resource Repository, you can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

LetsMT! Resource Repository is distributed in the hope that it will be
useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with LetsMT! Resource Repository.  If not, see
<http://www.gnu.org/licenses/>.
