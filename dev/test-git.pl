#!/usr/bin/perl


use lib "$ENV{HOME}/LetsMT-repository/perllib/LetsMT/lib";

use LetsMT::Resource;
use LetsMT::Repository::Storage;
use LetsMT::Repository::StorageManager;
use LetsMT::Repository::GroupManager;
use LetsMT::Repository::Storage::Git;

my $storage = new LetsMT::Repository::Storage('git');

my $groups = LetsMT::Repository::GroupManager::get_groups_for_user( 'user' );
my $branch = new LetsMT::Repository::StorageManager::Branch();
$branch->find(
        name           => $params{name},
        user           => 'user',
        groups         => $groups,
        slot           => 'corpus100',
    );

my $list = $storage->list( repos => 'corpus100',
			   dir => 'user',
			   branch => $branch );
print $list;


my %rev = $storage->revisions( 'corpus100/user/uploads/pdf/test.pdf' );
print join("\n", keys %rev);

my $list = $storage->list( repos => 'corpus100',
			   dir => 'user/uploads/pdf/test.pdf',
			   branch => $branch,
			   revision => 'HEAD');
print $list;

my $list = $storage->list( repos => 'corpus100',
			   dir => 'user/uploads/pdf/test.pdf',
			   branch => $branch,
			   revision => '1981980');
print $list;

my $target;
foreach my $r (keys %rev){
    print "checkout revision $r\n";
    $storage->export( repos => 'corpus100',
		      src => 'user/uploads/pdf/test.pdf',
		      rev => $r,
		      trg => \$target );
    print $target;
}





my $list = $storage->list( repos => 'corpus100',
			   dir => 'user/uploads/pdf/test3.pdf',
			   branch => $branch,
			   revision => 'HEAD');
print $list;

$storage->export( repos => 'corpus100',
		  src => 'user/uploads/pdf/test3.pdf',
		  trg => \$target );
print $target;

$storage->export( repos => 'corpus100',
		  src => 'user/uploads/pdf/test3.pdf',
		  rev => 'HEAD',
		  trg => \$target );
print $target;

$storage->export( repos => 'corpus100',
		  src => 'user/uploads/pdf/test3.pdf',
		  rev => 'ca8844d',
		  trg => \$target );
print $target;
