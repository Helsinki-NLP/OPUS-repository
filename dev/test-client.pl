use IO::Socket::INET;

# from http://xmodulo.com/how-to-write-simple-tcp-server-and-client-in-perl.html 

# auto-flush on socket
$| = 1;
 
# create a connecting socket
my $socket = new IO::Socket::INET (
    PeerHost => 'localhost',
    PeerPort => '15555',
    Proto => 'tcp',
    );
die "cannot connect to the server $!\n" unless $socket;
print "connected to the server\n";



# data to send to a server
# my $req = "hallo\nCLASSIFIER=cld2\nLANGHINT=de\n";
my $req = "hallo\nCLASSIFIER=cld2\n";
my $size = $socket->send($req);
print "sent data of length $size\n";
$socket->send('<<<CLASSIFY>>>');

# notify server that request has been sent
shutdown($socket, 1);
 
# receive a response of up to 1024 characters from server
my $response = "";
$socket->recv($response, 1024);
print "received response: $response\n";
 
$socket->close();
