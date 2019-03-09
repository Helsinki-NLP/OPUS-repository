

use Inline::Python;


($lang, $reliable, $details) =  detect("This is a house.");
print $lang;

($lang,$conf) = detect_with_langid("This is a house.");
print "$lang $conf\n";
($lang,$conf) = detect_with_langid("This is a Haus.");
print "$lang $conf\n";
($lang,$conf) = detect_with_langid("Haus thisis.");
print "$lang $conf\n";
($lang,$conf) = detect_with_langid("gemischter Text");
print "$lang $conf\n";

use Inline Python => <<'END_OF_PYTHON_CODE';
import pycld2 as cld2
import langid
from langid.langid import LanguageIdentifier, model
identifier = LanguageIdentifier.from_modelstring(model, norm_probs=True)

def detect(s,l=""):
    if (l != ""):
       isReliable, textBytesFound, details = cld2.detect(s, bestEffort=True, hintLanguage=l)
    else:
       isReliable, textBytesFound, details = cld2.detect(s, bestEffort=True)
    return (details[0][1],isReliable,details)
def detect_with_langid(s): 
    return identifier.classify(s)
END_OF_PYTHON_CODE
 
