
use Regexp::Common qw /URI/;

my @examples = ('http://www.helsinki.fi/test',
		'ftp://helsinki.fi/hallo/here',
		'ftp://-helsinki.fi',
		'http://helsinki.fi/~tiedeman',
		'https://helsinki.fi/~tiedeman',
		'ftp://helsinki.fi-/test',
		'http://helsinki_)_.fi/test',
		'http://helsi nki.fi/test',
		'http://helsi nki.fi/test',
		'http://helsi "nki.fi/test',
		'http://helsi nki.fi/test test');

foreach (@examples){
    print "$_\n";
    /^$RE{URI}{HTTP}{-keep}$/ ? print "valid $2 ($2,$3,$7,$8)\n" : print "invalid http\n";
    /^$RE{URI}{HTTP}{-scheme => 'https?'}{-keep}$/ ? print "valid $2 ($2,$3,$7,$8)\n" : print "invalid http\n";
    /^$RE{URI}{HTTP}{-scheme => '(ht|f)(tps?)'}{-keep}$/ ? print "valid $3$4 ($3$4,$5,$9,$10)\n" : print "invalid http\n";
    /^$RE{URI}{FTP}{-keep}$/  ? print "valid $2 ($1,$2,$3,$4)\n" : print "invalid ftp\n";
    /^$RE{URI}{-keep}$/       ? print "valid uri ($1)\n" : print "invalid uri\n";
    print "\n";
}

