#!/usr/bin/perl


use lib "$ENV{HOME}/LetsMT-repository/perllib/LetsMT/lib";

use LetsMT::Resource;
use LetsMT::Lang::Detect;
use Lingua::Identify::Blacklists qw/:all/;
use Lingua::Identify::CLD;
use Lingua::Identify qw(:language_identification);


@test = LetsMT::Lang::Detect::detect_language_with_cld("Hallo Welt!");
@test = LetsMT::Lang::Detect::detect_language_with_cld2("Hallo Welt!");
@test = LetsMT::Lang::Detect::detect_language_with_cld2("Hallo");
@test = LetsMT::Lang::Detect::detect_language_with_cld2("Hallo",'de');
@test = LetsMT::Lang::Detect::detect_language_with_lingua("Hallo Welt!");
@test = LetsMT::Lang::Detect::detect_language_with_langid("Hallo Welt!");


my $CLD = new Lingua::Identify::CLD;

$detected = &detect_language_string( "This is a gemischter Text aus dem house", 'en' );
print $detected;
$detected = &identify( "This is a gemischter Text aus dem house" );
print $detected;
$detected = &identify( "gemischter" );
print $detected;
($lang, $id, $conf) = $CLD->identify( "This is a gemischter Text aus dem house" );
($lang, $id, $conf) = $CLD->identify( "gemischter" );

$id = langof( "gemischter" );



$detected = &detect_language_string( "This is a gemischter Text aus dem house", 'de' );
print $detected;

($detected,$reliable,$details) = &detect_language_string( "gemischter", 'de' );
print $detected;
