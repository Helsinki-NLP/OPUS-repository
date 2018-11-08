#!/usr/bin/perl
#-*-perl-*-

=head1 NAME

25_Repository_API_Job.t - test I<Job> API

=head1 DESCRIPTION

This script tests the following assertions:

Calling the I<Job> API via the C<WebService> module, ...

=over 2

=cut


use strict;
use warnings;

use open qw(:std :locale);

use FindBin qw($Bin);
use lib ("$Bin/../../lib", "$Bin/..");

use Scaffold;
use Test::More;
use File::Slurp;

use LetsMT::WebService;
use LetsMT::Repository::Result;
use LetsMT::Resource;

# Prepare test data
my $id   = int( rand(999999999999) );
my $slot = 'slot_name_' . $id;

my ($uid, $gid) = Scaffold::add_user;

my $backend_type = shift(@ARGV) || $ENV{VC_BACKEND};

my $resource = new LetsMT::Resource( slot => $slot, user => $uid );
LetsMT::WebService::put(
    $resource->path_down,
    uid => $uid,
    gid => $gid,
    type => $backend_type
);


#############################################################################
# POSITIVE TESTS
#############################################################################

=item *

after you upload a job-description file to a slot ... (put_file)

=cut

$resource = new LetsMT::Resource(
    slot => $slot,
    user => $uid,
    path => 'uploads/job.xml',
);
my $result = LetsMT::WebService::put_file( $resource, 'data/job/job_description.xml' );
is( $result, 1, "PUT storage, upload job description file" );


=item *

you can submit the file as a job, ... (post_job)

=cut

$resource = new LetsMT::Resource(
    slot => $slot,
    user => $uid,
    path => 'uploads/job.xml',
);
$result = LetsMT::WebService::post_job( $resource );
is( $result, 1, "POST job, submit job" );


=item *

... which will have the job executed on the SGE grid engine
and finished within a reasonable amount of time.

=cut

$resource = new LetsMT::Resource(
    slot => $slot,
    user => $uid,
    path => 'uploads/job.xml',
);

my $max_count = 30; # number of tries
my $count     = 0;  # counter of tries
my $content;

# do until file is present or max_count is reached
print "waiting for jobs to finish ";
do {
    $count++;
    $result  = LetsMT::WebService::get_meta( $resource );
    my $dom  = xml_to_dom ( $result );
    $content = $dom->findvalue('//list/entry/job_status');
    print ($count % 5 ? '.' : '*');
    sleep 1 if ($content ne ('finished with 1 failed command(s)')); # wait for jobs to finish
} until ( $content eq ('finished with 1 failed command(s)') || $count > $max_count );
print "\n";
ok( $count <= $max_count, '- no time-out while waiting for job to finish' );


=item *

You can query metadata of a job description
that has been finished ... (get_meta)

=cut

$result = LetsMT::WebService::get_meta( $resource );
my $dom = xml_to_dom( $result );


=item *

... and it will show successful commands (ls, date, ...)
as 'done' ...

=cut

is( $dom->findvalue('//list/entry/command_1'), 'done',
    '- check content: command_1 is done'
);
is( $dom->findvalue('//list/entry/command_2'), 'done',
    '- check content: command_2 is done'
);
is( $dom->findvalue('//list/entry/command_3'), 'done',
    '- check content: command_3 is done'
);


=item *

... and failed commands (e.g. cd to nonexisting directory)
as 'failed'.

=cut

is( $dom->findvalue('//list/entry/command_4'), 'failed',
    '- check content: command_4 is failed'
);


=item *

you can resubmit a job description file. (put_job)

=cut

$resource = new LetsMT::Resource(
    slot => $slot,
    user => $uid,
    path => 'uploads/job.xml',
);
($result,$content) = LetsMT::WebService::put_job( $resource );
is( $result, 1, "PUT job, resubmit job" );


=item *

you can check the status of a (re)submitted job
-- which will be 'pending' during job execution. (get_job)

=cut

$resource = new LetsMT::Resource(
    slot => $slot,
    user => $uid,
    path => 'uploads/job.xml',
);
$result = LetsMT::WebService::get_job( $resource );
my $result_hash = xml_to_hash( $result, 1 );
my $message = $$result_hash{message};
my $ok = 0;
$ok = 1 if ($message=~/(finished|pending|running)/i);
is ( $ok, 1, "GET job, check status of resubmitted job, check status");

# is_deeply(
#     xml_to_hash( $result, 1 ),
#     success_hash( "/job/$slot/$uid/uploads/job.xml", "GET", "pending" ),
#     "GET job, check status of resubmitted job, check status"
# );



=item *

The metadata of a (re)submitted job description will also show the status,
as well as the job ID.

=cut

$resource = new LetsMT::Resource(
    slot => $slot,
    user => $uid,
    path => 'uploads/job.xml',
);
$result = LetsMT::WebService::get_meta( $resource );
$dom = xml_to_dom( $result );
$message = $dom->findvalue( '//list/entry/job_status' );
$message =~s/(finished|pending|running)//i;
my $status = $1;
is( $message,
    'submitted to grid engine with status: ',
    '- check content: job status is '.$status
);
ok( $dom->exists( '//list/entry/job_id' ), '- check content: job ID exists' );

my $jobID = $dom->findvalue( '//list/entry/job_id' );


=item *

you can delete a job ... (del_job)

=cut

$resource = new LetsMT::Resource(
    slot => $slot,
    user => $uid,
    path => 'uploads/job.xml',
);
$result = LetsMT::WebService::del_job( $resource );
sleep 3;
is( $result, 1, "DELETE job, delete a job" );


=item *

... and it will no longer be found in the system. (get_job)

=cut

$resource = new LetsMT::Resource(
    slot => $slot,
    user => $uid,
    path => 'uploads/job.xml',
);
$result = LetsMT::WebService::get_job( $resource );
is_deeply(
    xml_to_hash( $result, 1 ),
    success_hash( "/job/$slot/$uid/uploads/job.xml", "GET", "no job with ID '$jobID' found" ),
    "GET job, check that deleted job is gone, check status"
);


#############################################################################
# NEGATIVE TESTS
#############################################################################




#############################################################################
# CLEAN UP
#############################################################################

sub cleanup
{
    # Delete slot
    $resource = new LetsMT::Resource( slot => $slot );
    LetsMT::WebService::del(
        $resource->path_down,
        uid    => $uid,
        action => 'delete_meta',
    );

    Scaffold::cleanup;
}

=back

=cut


&cleanup;

done_testing;


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
