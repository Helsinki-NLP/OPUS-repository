#!/usr/bin/perl -C
# -*-perl-*-

# called from the apache sites file

use strict;
use warnings;

use open qw(:std :utf8);

use LetsMT::WWW::ModPerlHandler;

use LetsMT::Repository::GroupManager;
use LetsMT::Repository::StorageManager;
use LetsMT::Repository::AdminManager;
use LetsMT::Repository::MetaManager;

use Log::Log4perl qw(get_logger :levels);


# Make sure we are in a sane environment.
$ENV{MOD_PERL} or die "not running under mod_perl!";

# Set umask to rw-rw-rw- so that new log files are writeable
umask 0000;

# Initiate Log4perl by loading conf file and reload if it changes every 60 sec
Log::Log4perl->init_and_watch( $ENV{LOG4PERLCONF}, 60 );
get_logger("LetsMT")->info("initiated Log4perl from $ENV{LOG4PERLCONF}");

umask 0027;

# make sure that we always use utf-8!
# (for all kinds of system calls etc)
$ENV{LC_ALL} = 'en_US.UTF-8';



# mount a compressed file system if fusecompress is installed
# TODO: should we move this to the startup scripts? or add to fstab?
#
# the good thing about having it here:
# - we can check whether fusecompress is installed before mounting
#   (if it isn't it doesn't matter -- we will just use a plain uncompressed FS)

if (`which fusecompress`){
    $ENV{LETSMTUSER} = 'www-data' unless (defined $ENV{LETSMTUSER});
    my $rootdir = $ENV{LETSMTDISKROOT} || '/var/lib/letsmt/'.$ENV{LETSMTUSER};
    my @dir = split(/\/+/,$rootdir);
    my $user = pop(@dir);
    # push(@dir,'compressed');
    $rootdir = join('/',@dir,'compressed');
    my $compdir = join('/',@dir,'.compressed');
    my ($login,$pass,$uid,$gid) = getpwnam($user);
    unless (-d $rootdir){
	mkdir $rootdir;
	$uid ? chown $uid,$gid,$rootdir : chmod 0777,$rootdir;
    }
    unless (-d $compdir){
	mkdir $compdir;
	$uid ? chown $uid,$gid,$compdir : chmod 0777,$compdir;
    }
    system('fusecompress','-c','lzma','-o','allow_other',$compdir,$rootdir) || 
	get_logger("LetsMT")->warn("could not fusemount $rootdir");
}


1;


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
