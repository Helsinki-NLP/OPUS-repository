
# needed for the layout-mode conversion
use IPC::Run qw(run start pump finish timeout);


$input = 'D2.1.pdf';
$output = 'D2.1.xml';



eval{
    my ($in,$out,$err);
    $success = run ['pdf2xml', '-o', $output, $input], \$in, \$out, \$err, timeout( 1 );
};
if ($@){
    print "crashed";
}
else{
    print "success $success";
}


print "now done ....";
