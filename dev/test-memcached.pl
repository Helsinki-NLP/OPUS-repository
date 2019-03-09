
## does not seem to work with table DB
## https://fallabs.com/tokyotyrant/spex.html

# Table database supports "mode", "bnum", "apow", "fpow", "opts", "rcnum", "lcnum", "ncnum", "xmsiz", "dfunit", and "idx". The tuning parameter "capnum" specifies the capacity number of records. "capsiz" specifies the capacity size of using memory. Records spilled the capacity are removed by the storing order. 

use Cache::Memcached;

my $memd = Cache::Memcached->new();
$memd->set_servers(['localhost:1980']);

$memd->set('one', 'first');
$memd->set('two', 'second');
$memd->set('three', 'third');

my $val = $memd->get('one');
printf("one: %s\n", $val);

$val = $memd->get_multi('one', 'two', 'three');
printf("one: %s\n", $val->{one});
printf("two: %s\n", $val->{two});
printf("three: %s\n", $val->{three});

$memd->delete('one');
$memd->delete('two');
$memd->delete('three');


