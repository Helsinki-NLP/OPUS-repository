
use File::LibMagic;



$LIBMAGIC = File::LibMagic->new();
$info = $LIBMAGIC->info_from_filename('file1.tmx');
print $info;


$info = $LIBMAGIC->info_from_filename($ARGV[0]);
print $info;
