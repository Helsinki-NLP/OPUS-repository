

use utf8;
use Encode qw/decode encode/;

my $str= "kaÅ¾ociÅ?Å¡";


print decode('utf8',$str);
