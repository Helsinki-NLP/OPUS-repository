#!/usr/bin/perl


use lib "$ENV{HOME}/LetsMT-repository/perllib/LetsMT/lib";
use LetsMT::Repository::MetaManager;

use utf8;
use Encode qw /encode decode/;

my $metaDB = new LetsMT::Repository::MetaManager(-host => 'localhost', -port => 1980);
$metaDB->open_read();

my $message = '';
$result = $metaDB->search_xml( 1, \$message, 
			       { # STARTS_WITH__ID_ => 'www.goethe.de/opus',
				  _ID_ => 'www.goethe.de/opus/uploads/crawl.tar.gz',
				 #   _ID_ => 'www.helsinki.fi/opus/uploads/crawl.tar.gz',
				 # STARTS_WITH__ID_ => 'www.helsinki.fi/opus',
				 # STARTS_WITH__ID_ => 'corpus100/user/uploads',
				 # STARTS_WITH__ID_ => 'corpus100',
				   # STARTS_WITH_imported_from => 'uploads/crawl.tar.gz:',
			       } );



foreach my $h1 (values %$result){
    if (ref($h1) eq 'ARRAY'){
	foreach my $a (@$h1){
	    if (ref($a) eq 'HASH'){
		foreach my $h2 (values %$a){
		    if (ref($h2) eq 'ARRAY'){
			foreach my $a2 (@$h2){
			    # utf8::decode($a2);
			    unless (utf8::is_utf8($a2)){
				print "invalid: '$a2'\n";
			    }
			    else{
				encode('UTF-8',$a2);
			    }
			}
		    }
		    else{
			# utf8::decode($h2);
			unless (utf8::is_utf8($h2)){
			    print "invalid '$h2'\n";
			}
			else{
			    encode('UTF-8',$h2);
			}
		    }
		}
	    }
	}
    }
}
