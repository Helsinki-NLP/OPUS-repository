#!/usr/bin/perl


use lib "$ENV{HOME}/LetsMT-repository/perllib/LetsMT/lib";
use LetsMT::Tools;

my $dir = 'tmp';

# if (&run_cmd('find', "$dir/small", '-type', 'f', '|', 'split', '-l', '10', '-', $dir.'_')){
#     my @files = glob("${dir}_??");
#     foreach (@files){
# 	if (&run_cmd('tar','-czf',"$_.tar.gz",'-T',$_,'--transform','s#^tmp/##')){
# 	    print "ok\n";
# 	}
#     }
# }



&safe_system('find', "$dir/small", '-type', 'f', '|', 'split', '-l', '10', '-', $dir.'_');
my @files = glob("${dir}_??");
foreach (@files){
    &safe_system('tar','-czf',"$_.tar.gz",'-T',$_,'--transform','s#^tmp/##');
}
