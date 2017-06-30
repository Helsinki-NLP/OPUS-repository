package LetsMT::Tools::Strings;

=head1 NAME

LetsMT::Tools::Strings

=head1 DESCRIPTION

String manipulation/matching tools

=cut

use strict;
use Log::Log4perl qw(get_logger :levels);

use Exporter 'import';
our @EXPORT = qw(
    lcs lcsr strdiff infix_diff letter_infix_diff
);
our %EXPORT_TAGS = ( all => \@EXPORT );


=head2 C<lcsr>

 $score = &lcsr ($string1, $string2)

Compute the Longest Common Subsequence Ratio between two given strings $string1 and $string2 (based on edit distance)

=cut


sub lcsr{
    my ($str1,$str2)=@_;
    my $score=&lcs($str1,$str2);
    if (length($str1)>length($str2)){
        return $score/length($str1);
    }
    if (length($str2)>0){
        return $score/length($str2);
    }
    return 0;
}


sub letter_infix_diff{
    my ($str1,$str2) = @_;

    # ignore all non-letters (replace with '_')
    $str1 =~s/\P{L}/_/sg;
    $str2 =~s/\P{L}/_/sg;

    # merge multiple non-letter sequences
    $str1 =~s/\_+/\_/gs;
    $str2 =~s/\_+/\_/gs;

    return infix_diff($str1,$str2);
}


sub infix_diff{
    my ($org1,$org2) = @_;

    # ignore case
    my $str1 = lc($org1);
    my $str2 = lc($org2);

    my @char1 = split(//,$str1);
    my @char2 = split(//,$str2);

    my $max = $#char1 > $#char2 ? $#char1 : $#char2;

    my ($a,$b);
    for ($a=0;$a<=$max;$a++){
        last if ($char1[$a] ne $char2[$a]);
    }
    for ($b=1;$b<=$max+1;$b++){
        last if ($char1[-$b] ne $char2[-$b]);
    }

    my $infix1 = substr ($org1,$a,$#char1-$b-$a+2);
    my $infix2 = substr ($org2,$a,$#char2-$b-$a+2);

    return ($infix1,$infix2);
}

=head2 C<lcs>

 $length = &lcs ($string1, $string2 [,\%trace [,$printMatrix ] ] )

Compute the length of the Longest Common Subsequence (LCS) of two given strings $string1 and $string2.

Returns the length of the LCS. 

If \%trace is given: return also a trace back the path of the best match.
If $printMatrix is true: print the character matching matrix.

=cut


sub lcs {
    my ($src,$trg,$trace,$printMatrix)=@_;
    my (@l,$i,$j);
    my @src_let=split(//,$src);           # split string into char
    my @trg_let=split(//,$trg);
    unshift (@src_let,'');
    unshift (@trg_let,'');

    for ($i=0;$i<=$#src_let;$i++){        # initialize the matrix
        $l[$i][0]=0;
    }
    for ($i=0;$i<=$#trg_let;$i++){
        $l[0][$i]=0;
    }

    for $i (1..$#src_let){
        for $j (1..$#trg_let){
            if ($src_let[$i] eq $trg_let[$j]){
                $l[$i][$j]=$l[$i-1][$j-1]+1;
            }
            else{
                if ($l[$i][$j-1]>$l[$i-1][$j]){
                    $l[$i][$j]=$l[$i][$j-1];
                }
                else{
                    $l[$i][$j]=$l[$i-1][$j];
                }
            }
        }
    }

    if (ref($trace) eq 'HASH'){                  # save the trace of character
        $i=$#l;                                  # matches if %trace is defined
        $j=$#{$l[0]};
        while (($i>0) and ($j>0)){
            if ($l[$i][$j]==$l[$i-1][$j]){
                $$trace{$i}{$j}=$l[$i][$j]-$l[$i-1][$j];
                $i-=1;
            }
            elsif($l[$i][$j]==$l[$i][$j-1]){
                $$trace{$i}{$j}=$l[$i][$j]-$l[$i][$j-1];
                $j-=1;
            }
            else{
                $$trace{$i}{$j}=$l[$i][$j]-$l[$i-1][$j-1];
                $i-=1;
                $j-=1;
            }
        }
    }
 
    if ($printMatrix){
        print '   ';
        foreach (0..$#src_let){
            printf "%2s ", $src_let[$_];
        }
        print "\n";
      
        foreach (0..$#trg_let){
            my $i;
            printf "%2s ", $trg_let[$_];
            foreach $i (0..$#src_let){
                printf "%2d",$l[$i][$_];
                print " ";
            }
            print "\n";
        }
    }

    return $l[$#src_let][$#trg_let];
}


#####################################################################
# strdiff($src,$trg,\%NonMatchPairs)'
#--------------------------------------------------------------------
# compare 
#####################################################################

sub strdiff{
    my $src = shift;
    my $trg = shift;
    my $res = shift || {};

    my %trace;
    my $lcs=&lcs($src,$trg,\%trace);

    my @SRC=split(//,$src);
    my @TRG=split(//,$trg);

    my $i=1;
    my $j=1;

    my $x=1;
    my $y=1;
    my ($srcnot,$trgnot)=('','');

    my $matches='';
    my $nonmatches='';
    my $SrcNonMatch='';
    my $TrgNonMatch='';

    foreach $i (sort {$a <=> $b} keys %trace){
        foreach $j (sort {$a <=> $b} keys %{$trace{$i}}){
            if ($trace{$i}{$j}){
                $matches.=$SRC[$i-1];
                while ($x<$i){
                    $srcnot.=$SRC[$x-1];
                    $x++;
                }
                while ($y<$j){
                    $trgnot.=$TRG[$y-1];
                    $y++;
                }
                $x++;
                $y++;
                if ($srcnot or $trgnot){
                    $$res{$srcnot}{$trgnot}++;
                    $SrcNonMatch.=$srcnot.'*';
                    $TrgNonMatch.=$trgnot.'*';
                    $nonmatches.='('.$srcnot.'|'.$trgnot.').*';
                }
                else{
                    if (not $nonmatches){
                        $nonmatches='.*';
                        $SrcNonMatch.='*';
                        $TrgNonMatch.='*';
                    }
                }
                ($srcnot,$trgnot)=('','');
            }
            else{
                if ($matches!~/\*$/){
                    $matches.='*';
                }
            }
        }
    }
    while ($x<=@SRC){
        $srcnot.=$SRC[$x-1];
        $x++;
    }
    while ($y<=@TRG){
        $trgnot.=$TRG[$y-1];
        $y++;
    }
    if ($srcnot or $trgnot){
        $$res{$srcnot}{$trgnot}++;
        $nonmatches.='('.$srcnot.'|'.$trgnot.')';
        $SrcNonMatch.=$srcnot;
        $TrgNonMatch.=$trgnot;
    }
    return ($lcs,$nonmatches,$matches,$SrcNonMatch,$TrgNonMatch);
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