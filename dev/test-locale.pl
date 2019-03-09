
# use Locale::Country::Multilingual {use_io_layer => 1};

# my $lcm = Locale::Country::Multilingual->new();
# $lcm->set_lang('fr'); 
# print $lcm->code2country('DE');


use utf8;
use Locales::Language; #  ( 'de' );  # use German language
 
my $en = new Locales::Language('de');
my $de = new Locales::Language('de');

print $de->getLocale, " => ",
    $de->code2language ( "en" ), " / ",
    $de->language2code ( "English" ), "\n";

 
print $de->getLocale, " => ",
    $de->code2language ( "en" ), " / ",
    $de->language2code ( "Englisch" ), "\n";




use Locale::Codes::LangFam;
@codes   = all_langfam_codes();
@names   = all_langfam_names();

use Locale::Codes::LangVar;

@codes   = all_langvar_codes();



use Locale::Codes::Country;

@codes   = all_country_codes();


use Locale::Language;
use Locale::Codes::LangExt;

say(code2language('en'));        # $lang gets 'English'
say(language2code('French'));    # $code gets 'fr'

@codes   = all_language_codes();
@names   = all_language_names();

@codes   = all_langext_codes();
# @codes   = all_langext_codes(LOCALE_LANG_ALPHA_2);

use Locale::Codes::Script;
@codes   = all_script_codes();

@codes   = all_language_codes(LOCALE_LANG_ALPHA_3);
say(language2code( code2language('fr'), LOCALE_LANG_ALPHA_3 ));
say(language2code( code2language('fre', LOCALE_LANG_ALPHA_3) ));

say(language2code('French', LOCALE_LANG_TERM));

print '';


sub say{ print $_[0],"\n"; }
