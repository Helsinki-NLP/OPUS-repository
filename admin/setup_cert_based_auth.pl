#!/usr/bin/perl -w
#-*-perl-*-

use strict;
use Getopt::Long;

#my $optsref = &handle_opts();

my %opts = (
    'projname'   => "letsmt2",
    'apacheconf' => "/etc/apache2/sites-available/letsmt",
    'country'    => 'SE',
    'city'       => 'Uppsala',
    'company'    => 'LetsMT',
    'user'       => 'developers@localhost',
    'username'   => 'Developers LetsMT',
    'ssl_sysdir' => '/etc/ssl',

    ## On interactive questions, always give this a the "Common name"
    ## Must be the fully qualified domain name of the server
    'site' => `hostname -A`
);

chomp( $opts{'site'} );
$opts{'site'} =~ s/\s//g;
&handle_opts( \%opts );

my $ssl_targetdir = $opts{ssl_sysdir} . "/" . $opts{projname};
my $pass_cakey    = "pass:''";
my $pass_cacsr    = "pass:''";

&init();

## CA key, CA csr, self-signed crt
&gen_key("private/ca.key");
&gen_csr( "private/ca.key", "ca.csr", $opts{'site'} );
&gen_crt( "private/ca.key", "ca.csr", "ca.crt" );

## server key, csr and CA-signed crt
&gen_key("server/keys/$opts{site}.key");
&gen_csr( "server/keys/$opts{site}.key", "server/keys/$opts{site}.csr",
    $opts{'site'} );
&gen_crt_ca(
    "private/ca.key", "server/keys/$opts{site}.csr",
    "ca.crt",         "server/certificates/$opts{site}.crt"
);

## user key, csr and CA-signed crt
&gen_key("user/keys/$opts{user}.key");
&gen_csr( "user/keys/$opts{user}.key", "user/keys/$opts{user}.csr",
    $opts{'username'} );
&gen_crt_ca(
    "private/ca.key", "user/keys/$opts{user}.csr",
    "ca.crt",         "user/certificates/$opts{user}.crt"
);

## place certs in place
if ( !-d "/etc/apache2/ssl_certs" ) {
    die() unless ( mkdir("/etc/apache2/ssl_certs") );
}
die()
    unless (
    syslog(
        "cd $ssl_targetdir && tar -cf - server/certificates/$opts{site}.crt server/keys/$opts{site}.key ca.crt | tar -C /etc/apache2/ssl_certs -xf -"
    ) == 0
    );

#print STDERR "Check steps against http://www.garex.net/apache/\n";
#print STDERR "\n(don't forget a2enmod ssl and RESTART (not reload) apache)\n";

#&sed($opts{'apacheconf'},
#     'SSLCertificateFile\s.*$' => 'SSLCertificateFile /etc/apache2/ssl_certs/server/certificates/'.$opts{site}.'.crt',
#     'SSLCertificateKeyFile\s.*$' =>  'SSLCertificateKeyFile /etc/apache2/ssl_certs/server/keys/'.$opts{site}.'.key',
#     'SSLCertificateChainFile\s.*$' =>  'SSLCertificateChainFile /etc/apache2/ssl_certs/server/certificates/'.$opts{site}.'.crt',
#     'SSLCACertificateFile\s.*$' =>  'SSLCACertificateFile /etc/apache2/ssl_certs/ca.crt',
#     'SSLCACertificatePath\s.*$' =>  'SSLCACertificatePath /etc/ssl/letsmt2/newcerts',
#     'SSLCARevocationPath\s.*$' =>  'SSLCARevocationPath /etc/ssl/letsmt2/crl',
#     'SSLOptions\s.*$' =>  'SSLOptions +StrictRequire',
#     'SSLVerifyClient\s.*$' =>  'SSLVerifyClient require',
#     'SSLVerifyDepth\s.*$' =>  'SSLVerifyDepth 2',
#    );

exit;

sub init {
    mkdir($opts{ssl_sysdir}) unless (-d $opts{ssl_sysdir});
    
    ## if the original is not backed up, do it now
    if ( -f "$opts{ssl_sysdir}/openssl.cnf"
        && !-f "$opts{ssl_sysdir}/openssl.cnf.ORIG" )
    {
        die("cannot make copy of openssl.cnf")
            unless (
            syslog(
                "cp $opts{ssl_sysdir}/openssl.cnf $opts{ssl_sysdir}/openssl.cnf.ORIG"
            ) == 0
            );
    }
    if ( -f "$opts{ssl_sysdir}/openssl.cnf.ORIG" ) {
	    syslog(
	        "cp --backup=numbered $opts{ssl_sysdir}/openssl.cnf.ORIG $opts{ssl_sysdir}/openssl.cnf"
	    );
    }
    &sed(
        "$opts{ssl_sysdir}/openssl.cnf",
        'CA_default'     => $opts{'projname'},
        '^dir\s+=\s+.*$' => "dir = $ssl_targetdir",
        'cakey.pem'      => 'ca.key',
        'cacert.pem'     => 'ca.crt'
    );

    ## make dirs
    ##
    ## TODO: check if it is OK to continue when the dir already exists!
    ##
#    if ( -d $ssl_targetdir ) {
#        die("remove $ssl_targetdir first");
#    }

    mkdir($ssl_targetdir) unless (-d $ssl_targetdir);
    for my $D ( "newcerts", "certs", "crl", "private", "server", "user" ) {
        mkdir( $ssl_targetdir . "/" . $D ) unless (-d $ssl_targetdir."/".$D) ;
    }
    for my $D (
        "server/certificates", "server/keys",
        "user/certificates",   "user/keys"
        )
    {    #"server/requests", "user/requests",
        mkdir( $ssl_targetdir . "/" . $D );
    }

    ## setup openssl serial stuff
    syslog("echo 01 > $ssl_targetdir/serial") == 0 || die();
    syslog("touch $ssl_targetdir/index.txt") == 0  || die();
    syslog("echo unique_subject = no > $ssl_targetdir/index.txt.attr") == 0
        || die();
}

sub gen_key {
    my $out = shift;

    # for openssl v0.98
    die()
        unless (
        syslog(
            "cd $ssl_targetdir && openssl genrsa -out $out -passout $pass_cakey 1024"
        ) == 0
        );

#  for openssl v1.0
# die() unless(syslog("cd $ssl_targetdir && openssl genpkey -out $out -outform PEM -pass $pass_cakey -algorithm rsa") == 0);
}

sub gen_csr {
    my ( $key, $csr, $cn ) = @_;

    die()
        unless (
        syslog(
            "cd $ssl_targetdir && openssl req -inform PEM -outform PEM -new -key $key -out $csr -passin $pass_cakey -passout $pass_cacsr -multivalue-rdn -subj '/C="
                . $opts{'country'} . "/ST="
                . $opts{'city'} . "/O="
                . $opts{'company'} . "/OU="
                . $opts{'company'} . "/CN="
                . $opts{'site'} . "'"
        ) == 0
        );
}

sub gen_crt {
    my ( $key, $csr, $crt ) = @_;

    ## self-sign the CA certificate:
    die()
        unless (
        syslog(
            "cd $ssl_targetdir && openssl x509 -inform PEM -outform PEM -keyform PEM -req -days 3650 -in $csr -out $crt -signkey $key"
        ) == 0
        );

    ## verify the certificate contents, use the following command:
    die()
        unless (
        syslog("cd $ssl_targetdir && openssl x509 -in $crt -text >/dev/null")
        == 0 );
}

sub gen_crt_ca {
    my ( $key, $csr, $cacrt, $crt ) = @_;

    # ## sign the web server certificate with the CA key:
    die()
        unless (
        syslog(
            "cd $ssl_targetdir && openssl ca -days 3650 -in $csr -cert $cacrt -keyfile $key -out $crt -config $opts{ssl_sysdir}/openssl.cnf"
        ) == 0
        );

    ## verify cert
    die()
        unless (
        syslog("cd $ssl_targetdir && openssl x509 -in $crt -text >/dev/null")
        == 0 );

#  # ## export to a format commonly accepted by browsers
#  die() unless(syslog("cd $ssl_targetdir && openssl pkcs12 -export -clcerts -in $crt -inkey ./user/keys/$user.key -out ./user/certificates/$user.p12") == 0);
}

sub sed {
    my $file  = shift;
    my %repl  = @_;
    my $cont  = "";
    my %found = ();

    syslog("cp $file $file.bak.$$") == 0 || die($@);
    open( IN, $file ) || die();
    while (<IN>) {
        my $l = $_;
        foreach my $key ( keys %repl ) {
            if ( $l =~ s/$key/$repl{$key}/ ) {
                $found{$key} = 1;
            }
        }
        $cont .= $l;
    }
    close(IN);

    open( OUT, ">$file" ) || die();
    print OUT $cont;
    close(OUT);

    map { warn("No match for $_") unless ( $found{$_} ) } keys %repl;
}

sub syslog {
    print STDERR caller() . "]\t" . $_[0] . "\n";
    return system( $_[0] );
}

sub handle_opts {
    my $opts = shift;

    GetOptions(
        'projname=s'   => \$opts->{'projname'},
        'country=s'    => \$opts->{'country'},
        'city=s'       => \$opts->{'city'},
        'company=s'    => \$opts->{'company'},
        'ssl_sysdir=s' => \$opts->{'ssl_sysdir'},
        'user=s'       => \$opts->{'user'},
        'username=s'   => \$opts->{'username'},
        'site=s'       => \$opts->{'site'},
    );

    return \%opts;
}

#
# This file is part of LetsMT! Resource Repository.
#
# LetsMT! Resource Repository is free software: you can redistribute it
# and/or modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# LetsMT! Resource Repository is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with LetsMT! Resource Repository.  If not, see
# <http://www.gnu.org/licenses/>.
#