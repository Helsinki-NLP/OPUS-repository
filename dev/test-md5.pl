use Digest::MD5::File qw(dir_md5_base64 dir_md5_hex file_md5 file_md5_hex file_md5_base64 url_md5_hex);
 
my $md5 = Digest::MD5->new;
$md5->addpath('OPUS-repository/README');
$digest = $md5->hexdigest;

my $file = 'OPUS-repository/README'; 

$digest = file_md5($file);
$digest = file_md5_hex($file);
$digest = file_md5_base64($file);
 
# my $md5 = Digest::MD5->new;
# $md5->addurl('http://www.tmbg.com/tour.html');
# $digest = $md5->hexdigest;
 
# $digest = url_md5($url);
# $digest = url_md5_hex($url);
# $digest = url_md5_base64($url);
 
my $md5 = Digest::MD5->new;
$md5->adddir('tmp/small');
$digest = $md5->hexdigest;
 
$dir = 'tmp/small';
# my $dir_hashref = dir_md5($dir);    
$dir_hashref = dir_md5_hex($dir);    
$dir_hashref = dir_md5_base64($dir);
