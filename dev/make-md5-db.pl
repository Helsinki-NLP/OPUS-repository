
#
# make the md5 DB necessary for OPUS RR
#


use DBM_Filter;
use DB_File;

use Digest::MD5::File qw/dir_md5_hex file_md5_hex/;


my $dir    = shift(@ARGV) || die "no dir given";
my $dbfile = shift(@ARGV) || die "no db file given"; 


my $db = tie %md5db,"DB_File",$dbfile;
my $md5hash = dir_md5_hex($dir);

$db->Filter_Key_Push('utf8');
$db->Filter_Value_Push('utf8');

foreach (keys %{$md5hash}){
    $md5db{$_} = $$md5hash{$_} if ($$md5hash{$_});
}

