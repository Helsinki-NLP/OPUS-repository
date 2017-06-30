#!/usr/bin/env perl
#-*-perl-*-

use FindBin;
use Data::Dumper;
use Encode;

my $codefile   = $FindBin::Bin . '/ISO-639-2_8859-1.txt';
my $regionfile = $FindBin::Bin . '/DEFAULT_REGIONS.txt';

my $nonstandardcodes = $FindBin::Bin . '/NON_STANDARD_CODES.txt';

my %TwoToThree  = ();
my %ThreeToTwo  = ();
my %ThreeToName = ();
my %NameToThree = ();

&read_codefile($codefile);
&read_codefile($nonstandardcodes);

my %DefaultRegion = ();

open F, "<$regionfile" || die "cannot find codefile $regionfile!\n";
while (<F>) {
    next if (/^\#/);
    next if (/^\s*$/);
    chomp;
    my ( $lang, $country ) = split(/\t/);
    $lang                 = lc($lang);
    $country              = lc($country);
    $DefaultRegion{$lang} = $country;
}
close F;

print '## WARNING: Auto-generated file, do not edit by hand! ##

package LetsMT::Lang::ISO639;

use Exporter \'import\';
our @EXPORT = qw(
    iso639_TwoToThree 
    iso639_ThreeToTwo 
    iso639_ThreeToName 
    iso639_exists 
    iso639_AnyToTwo 
    iso639_AnyToLangTag 
    iso639_DefaultRegion
    iso639_NameToThree
    iso639_NameToTwo
);
%EXPORT_TAGS = ( all => \@EXPORT );
';

print Data::Dumper->Dump( [ \%ThreeToTwo ],    ['ThreeToTwo'] );
print Data::Dumper->Dump( [ \%TwoToThree ],    ['TwoToThree'] );
print Data::Dumper->Dump( [ \%ThreeToName ],   ['ThreeToName'] );
print Data::Dumper->Dump( [ \%NameToThree ],   ['NameToThree'] );
print Data::Dumper->Dump( [ \%DefaultRegion ], ['DefaultRegion'] );

print '
sub iso639_TwoToThree{
    my $code=shift;
    $code=lc($code);
    if (exists $TwoToThree->{$code}){
        return $TwoToThree->{$code};
    }
    $code =~s/[\_\-].*$//;
    if (exists $TwoToThree->{$code}){
        return $TwoToThree->{$code};
    }
    return $code;
}
';

print '
sub iso639_ThreeToTwo{
    my $id=shift;
    my $code=$id;
    $code=lc($code);
    if (exists $ThreeToTwo->{$code}){
        return $ThreeToTwo->{$code};
    }
    $code =~s/[\_\-].*$//;
    if (exists $ThreeToTwo->{$code}){
        return $ThreeToTwo->{$code};
    }
    return $id;
}
';

# ---> normalize language tag!

print '
sub normalize_langtag{
    return iso639_AnyToTwo(@_);
#    return iso639_AnyToLangTag(@_);
}
';

print '
sub iso639_DefaultRegion{
    my $lang = shift;
    $lang = lc($lang);
    if (exists $DefaultRegion->{$lang}){
        return $DefaultRegion->{$lang};
    }
    return uc($lang);  # this can be wrong if not all other mappings exist
}
';

# the following should handle variants of different types of language codes
# and create standard 2-letter codes that we like to use in the form: ll_CC
# (ll=language code, CC = country/region code)
#

print '
sub iso639_AnyToLangTag{
    my $code=shift;

    # country/region code
    my $region=undef;
    if ($code =~s/[\_\-](.*)$//){
       $region = uc($1);
    }
    $code=lc($code);
    if (length($code) == 3){
      if (exists $ThreeToTwo->{$code}){
        $code = $ThreeToTwo->{$code};
      }
      else{
         # warn "unknown 3-letter language code $code\n!";
         ##
         ## leave the code or make it into 2 letters?!
         ## or find closest match?!?! or just produce an error and die?
         ##
      }
    }
    if (not defined $region){
       $region = iso639_DefaultRegion($code);
    }
    return $code."_".$region;
}
';

print '
sub iso639_AnyToTwo{
    my $lang=shift;
    my $code=$lang;
    $code =~s/[\_\-](.*)$//;
    if (length($code) == 3){
      if (exists $ThreeToTwo->{$code}){
        $code = $ThreeToTwo->{$code};
        return lc($code);
      }
#      else{
#        warn "\ncannot find mapping from 3-letter-code $code to 2-letters!\n";
#      }
    }
    return $code if (exists $TwoToThree->{$code});
    return &iso639_NameToTwo($lang);
#    return lc($code);
}
';

print '
sub iso639_ThreeToName{
    my $code=shift;
    $code=lc($code);
    if (exists $ThreeToName->{$code}){
        return $ThreeToName->{$code};
    }
    $code =~s/[\_\-].*$//;
    if (exists $ThreeToName->{$code}){
        return $ThreeToName->{$code};
    }
    return $code;
}
';

print '
sub iso639_NameToThree {
    my $name = shift;
    if ( exists $NameToThree->{$name} ) {
        return $NameToThree->{$name};
    }
    $name = ucfirst($name);                  # try with an upper-case letter
    if ( exists $NameToThree->{$name} ) {
        return $NameToThree->{$name};
    }
    return $name;
}

sub iso639_NameToTwo {
    return &iso639_ThreeToTwo( &iso639_NameToThree($_[0]) );
}
';

print '
sub iso639_exists{
    my $code=shift;
    #$code =~s/[\_\-].*$//;    # remove region code
    $code =~s/\_[a-zA-Z0-9]{2,3}$//;    # remove region code
    return 1 if (exists $ThreeToName->{$code});
    return 1 if (exists $TwoToThree->{$code});
    return 0;
}
';

print '
1;
';

sub read_codefile {
    my $codefile = shift;
    open F, "<$codefile" || die "cannot find codefile $codefile!\n";
    binmode(F, ':encoding(iso-8859-1)');
    while (<F>) {
        next if (/^\#/);
        next if (/^\s*$/);
        chomp;
        $_ = encode( 'utf8', $_ );
        my @arr  = split(/\|/);
        my $iso3 = shift(@arr);
        my $alt  = shift(@arr);
        my $iso2 = shift(@arr);

        my @names = ();
        foreach my $l (@arr) {
            push( @names, split( /\s*\;\s*/, $l ) );
        }
        $ThreeToName{$iso3} = $names[0];
        $ThreeToName{$alt} = $names[0] if ($alt);
        foreach (@names) {
            $NameToThree{$_} = $iso3;
        }
        if ($iso2) {
            $TwoToThree{$iso2} = $iso3;
            $ThreeToTwo{$iso3} = $iso2;
            $ThreeToTwo{$alt}  = $iso2 if ($alt);
        }
    }
    close F;
}


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
