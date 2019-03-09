#!/usr/bin/perl


use MIME::Lite;

$msg = MIME::Lite->new(
    To       =>'tiedeman@gmail.com',
    Subject  =>'Helloooooo, nurse!',
    Data     =>"How's it goin', eh?"
    );

#     From     =>'me@myhost.com',



# my $msg = MIME::Lite->new(
#   From    => 'jc@home.com',
#   To      => 'jorg.tiedemann@helsinki.fi',
#   Subject => 'attached file',
#   Data    => "The file is attached.\n"
#     );
# $msg->attach(
#   Path    => 'small.tar.gz',
#   Type    =>'AUTO'
#     );
# $msg->send;




# use Mail::Sendmail;
 
# %mail = ( To      => 'jorg.tiedemann@helsinki.fi',
#           From    => 'me@here.com',
#           Message => "This is a very short message"
#     );
 
# sendmail(%mail) or die $Mail::Sendmail::error;
 
# print "OK. Log says:\n", $Mail::Sendmail::log;





# use strict;
# use Email::Sender::Simple qw(sendmail);
# use Email::Simple;
# use Email::Simple::Creator;
 
# my $email = Email::Simple->create(
#   header => [
#     To      => '"joerg tiedemann" <jorg.tiedemann@helsinki.fi',
#     From    => '"Bob Fishman" <orz@example.mil>',
#     Subject => "don't forget to *enjoy the sauce*",
#   ],
#   body => "This message is short, but at least it's cheap.\n",
#     );
 
# sendmail($email);
