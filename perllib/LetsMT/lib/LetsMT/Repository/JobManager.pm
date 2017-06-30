package LetsMT::Repository::JobManager;

=head1 NAME

LetsMT::Repository::JobManager - manager for the job API

=head1 DESCRIPTION

Interacts with the Oracle (Sun) Grid Engine.

=cut

use strict;

use open qw(:std :utf8);

use XML::LibXML;
use File::Basename 'basename';
use File::Temp 'tempfile';

use LetsMT::Repository::MetaManager;
use LetsMT::Resource;
use LetsMT::WebService;
use LetsMT::Tools;
use LetsMT::Repository::Safesys;
use LetsMT::Corpus;
use LetsMT::Align;

use Data::Dumper;
use LetsMT::Repository::Err;
use Log::Log4perl qw(get_logger :levels);


=head1 FUNCTIONS

=head2 C<create_job>

 LetsMT::Repository::JobManager::create_job (
     path     => $path,
     uid      => $uid,
     commands => $commands,
     walltime => $walltime,
 )

Create a job descriptions file with the given command list and walltime
and upload it to the repository at the given path.

Returns: resource object of the created job

=cut

sub create_job {
    my %args = @_;

    my $path     = $args{'path'}     or raise( 12, 'path',         'error' );
    my $user     = $args{'uid'}      or raise( 12, 'user',         'error' );
    my $commands = $args{'commands'} or raise( 12, 'command list', 'error' );
    my $walltime = $args{'walltime'} || 10;
    my $queue    = $args{'queue'}    || 'letsmt';

    push my @cmd_array, map { { "command" => $_ } } $commands;

    # Build hash structure for XML job description
    my $hash_structure = {
        'wallTime' => [ $args{'walltime'} ],
        'queue'    => [ $args{'queue'} ],
        'commands' => @cmd_array,
    };

    # Get parser and write out to XML
    my $xmlParser = XML::Simple->new;
    my $xml       = $xmlParser->XMLout(
        $hash_structure,
        RootName      => 'letsmt-job',
        SuppressEmpty => 1
    );

    # upload xml string as file to repository
    my ( $fh, $file_name ) = tempfile(
        'job_description_XXXXXXXX',
        DIR    => $ENV{UPLOADDIR},
        UNLINK => 1,
    );

    # it seems that 'tempfile' is NOT affected by 'use open' above :-(
    binmode( $fh, ':encoding(utf8)' );

    print $fh $xml;
    close($fh) || raise( 8, 'could not close tmp job description file' );

    my $resource = LetsMT::Resource::make_from_path($path);
    LetsMT::WebService::post_file( $resource, $file_name, uid => $user )
        || raise( 8, 'could not upload job description file');

    # don't wait for cleanup but just remove the job description file 
    unlink($file_name);

    return $resource;
}


=head2 C<job_maker>

 LetsMT::Repository::JobManager::job_maker (
    $command,
    $path_elements,
    $args
 )

Create a job that will create jobs (running $command) for resources in the given path and submit them to the SGE using the letsmt_maker script.

=cut

sub job_maker{
    my ($command,$path_elements,$args) = @_;

    my $slot = shift(@{$path_elements});
    my $branch = shift(@{$path_elements});

    # create a new alignment job
    my $jobfile = join( '/',
        'storage', $slot, $branch,
        'jobs', 'run', @{$path_elements}
    );
    $jobfile .= '.'.$command;

    my $relative_path = join('/',@{$path_elements});

    my $argstr = '';
    foreach (keys %{$args}) {
        next if ($_ eq 'run');
        $argstr .=
            ' ' . &safe_path( $_ ) .
            ' ' . &safe_path( $args->{$_} );
    }

    # create job
    LetsMT::Repository::JobManager::create_job(
        path     => $jobfile,
        uid      => $args->{uid},
        walltime => 5,
        queue    => 'letsmt',
        commands => [
            'letsmt_make'
            . ' -u ' . &safe_path( $args->{uid} )
            . ' -s ' . &safe_path( $slot )
            . ' -p ' . &safe_path( $relative_path )
            . ' '    . &safe_path( $command )
            . $argstr
        ]
    );

    # and submit alignment job
    my $message;
    &submit(
        message => \$message,
        path    => $jobfile,
        uid     => $args->{uid},
    );
    return $jobfile;
}


=head2 C<run>

 LetsMT::Repository::JobManager::run (
    $command,
    $path_elements,
    $args
 )

Create jobs (running $command) for resources in the given path and submit them to the SGE.

=cut

sub run {
    my ($command,$path_elements,$args) = @_;

    if ($command eq 'align'){
        return run_align($path_elements, $args);
    }
    if ($command eq 'realign'){
        return run_realign($path_elements, $args);
    }
    elsif ($command eq 'import'){
        return run_import($path_elements, $args);
    }
}


=head2 C<run_align>

 LetsMT::Repository::JobManager::run_align (
    $path_elements,
    $args
 )

Create sentence alignment jobs for parallel resources in the given path
and submit them to the SGE
 The path should refer to a corpus root or its xml directory.

=cut

sub run_align {
    my $path_elements = shift;
    my $args = shift || {};

    my @sentalign = ();

    my $slot      = shift(@{$path_elements});
    my $branch    = shift(@{$path_elements});

    my $corpus    = LetsMT::Resource::make( $slot, $branch );
    my $resource  = @{$path_elements}
        ? LetsMT::Resource::make(
            $slot, $branch, join( '/', @{$path_elements} )
        )
        : undef;

    my %parallel = &find_parallel_resources($corpus,$resource,%{$args});

    my $count = 0;
    my %done  = (); 
    foreach my $src (keys %parallel) {
        foreach my $trg (keys %{$parallel{$src}}) {
            if (exists $done{$src}) {
                next if (exists $done{$src}{$trg});
            }
            my $SrcRes = LetsMT::Resource::make_from_storage_path($src);
            my $TrgRes = LetsMT::Resource::make_from_storage_path($trg);
            # swap if needed (language IDs should be sorted)
            if ( $SrcRes->language() gt $TrgRes->language() ) {
                ( $SrcRes, $TrgRes ) = ( $TrgRes, $SrcRes );
            }
            my $AlgRes = LetsMT::Align::make_align_resource($SrcRes, $TrgRes);

            &run_align_resource(
                $slot, $branch,
                $SrcRes->path(), $TrgRes->path(),
                $AlgRes->path(),
                $args
            );
            $done{$trg}{$src}=1;  ## avoid running the same pair twice
            $count++;
        }
    }
    return $count;
}


=head2 C<run_realign>

 LetsMT::Repository::JobManager::run_realign (
    $path_elements,
    $args
 )

Create sentence re-alignment jobs for resources in the given path
and submit them to the SGE.
The path may refer to a directory
(re-run alignment of all existing sentence alignment files below this path)
or a sentence alignment resource
(re-run alignment for this resource).

=cut

sub run_realign {
    my ($path_elements,$args) = @_;

    my @sentalign = ();
    my $path      = join('/',@{$path_elements});

    my $resource = LetsMT::Resource::make_from_storage_path( $path );
    my $files = &find_sentence_aligned( $resource, $args );

    my $count = 0;
    my %done = ();
    foreach my $s (keys %{$files}){
        my $SrcRes = LetsMT::Resource::make_from_storage_path($s);

        foreach my $t (keys %{$$files{$s}}){

            next if ($done{$$files{$s}{$t}});
            my $TrgRes = LetsMT::Resource::make_from_storage_path($t);
            my $AlgRes = 
                LetsMT::Resource::make_from_storage_path($$files{$s}{$t});

            &run_align_resource( $SrcRes->slot, $SrcRes->user,
                                 $SrcRes->path, $TrgRes->path, 
                                 $AlgRes->path, $args );
            $done{ $$files{$s}{$t} } = 1;
            $count++;
        }
    }
    return $count;
}


=head2 C<run_align_resource>

 LetsMT::Repository::JobManager::run_align_resource (
    $slot,
    $branch,
    $srcfile,
    $trgfile,
    $sentalign,
    $args
 )

Create a sentence alignment job for aligning two resources
(slot/branch/srcfile and slot/branch/trgfile)
and submit it to the SGE
C<$sentalign> is used as a basename for the job file
(C<$srcfile> is used if C<$sentalign> is not given).

=cut

sub run_align_resource {
    my ($slot, $branch, $srcfile, $trgfile, $sentalign, $args) = @_;

    # in case sentalign is not defined --> make from (srcfile,$trgfile)
    $sentalign = $srcfile.'-'.basename($trgfile) unless ($sentalign);

    # create a new alignment job
    my $jobfile = join('/','storage',$slot,$branch,
                           'jobs','align',$sentalign);

    # create the JOB file and post it

    my $job_resource = &create_job(
        path     => $jobfile,
        uid      => $args->{uid},
        walltime => 5,
        queue    => 'letsmt',
        commands => [
            'letsmt_align' 
            . ' -u ' . &safe_path( $branch )
            . ' -s ' . &safe_path( $slot )
            . ' -e ' . &safe_path( $srcfile )
            . ' -f ' . &safe_path( $trgfile )
        ],
    );

    # submit the new job via the JOB API

    if (LetsMT::WebService::post_job( $job_resource, 'uid' => $args->{uid} )) {
        my $resource = LetsMT::Resource::make( $slot, $branch, $sentalign );
        LetsMT::WebService::post_meta(
            $resource,
            status => 'waiting in alignment queue',
            uid    => $args->{uid}
        );
        return 1;
    }
    return 0;
}


=head2 C<run_import>

 LetsMT::Repository::JobManager::run_import (
    $path_elements,
    $args
 )

Create import jobs for resources in the given path and submit them to the SGE.
The path may refer to a directory (re-run import for all existing resources below this directory)
or a single resource.

=cut

sub run_import{
    my ($path_elements,$args) = @_;

    my @documents = ();
    my $path      = join('/',@{$path_elements});

    # create a new importer object for type checking
    # --> check if a certain file type can be handled by the import module!
    # --> we only use suffix-based lookups to avoid importing logfiles etc
    # 
    # (set 'local_root' to avoid creating temp-files)
    my $importer = new LetsMT::Import(local_root => '/tmp');

    if ($importer->suffix_lookup($path)){
        push(@documents,$path);
    }
    else{
        my $corpus = LetsMT::Resource::make_from_storage_path($path);
        my @files = &find_resources($corpus,$args);
        foreach my $p (@files){
            if ($importer->suffix_lookup($p)){
                push(@documents,$p);
            }
        }
    }

    my $count=0;
    foreach my $s (@documents){
        run_import_resource($s,$args);
        $count++;
    }
    return $count;
}


=head2 C<run_import_resource>

 LetsMT::Repository::JobManager::run_import_resource (
    $path_elements,
    $args
 )

Create an import job for a resource given by its path and submit it to the SGE.

=cut

sub run_import_resource{
    my ($path,$args) = @_;

    my @path_elements = split(/\/+/,$path);
    my $slot = shift(@path_elements);
    my $branch = shift(@path_elements);

    # create a new alignment job
    my $jobfile = join('/','storage',$slot,$branch,
                           'jobs','import',@path_elements);

    my $relative_path = join('/',@path_elements);

    # create the job file and post it

    my $job_resource = &create_job(
        path     => $jobfile ,
        uid      => $args->{uid},
        walltime => 5,
        queue    => 'letsmt',
        commands => [
            'letsmt_import'
            . ' -u ' . &safe_path( $branch )
            . ' -s ' . &safe_path( $slot )
            . ' -p ' . &safe_path( $relative_path )
        ],
    );

    # submit the new job via the JOB API

    if ( LetsMT::WebService::post_job( $job_resource, 'uid' => $args->{uid} ) ) {
        my $corpus = LetsMT::Resource::make( $slot, $branch );
        my $res = LetsMT::Resource::make( $slot, $branch, $relative_path );
        LetsMT::WebService::post_meta(
            $res,
            status => 'waiting in import queue',
            uid    => $args->{uid},
        );
        LetsMT::WebService::del_meta(
            $corpus,
            import_failed => $relative_path,
            uid           => $args->{uid},
        );
        LetsMT::WebService::put_meta(
            $corpus,
            import_queue => $relative_path,
            uid          => $args->{uid},
        );
        return 1;
    }
    return 0;
}


=head2 C<submit>

 LetsMT::Repository::JobManager::submit (
     path    => $path,
     uid     => $uid,
     message => $message,
 )

Submit a job to the SGE queue.

Returns: an XML-formatted status string.

=cut

sub submit {
    my %args    = @_;
    my $message = $args{message};
    my $path    = $args{path} || raise( 12, "parameter path", 'warn' );
    my $user    = $args{uid};

    my $logger = get_logger(__PACKAGE__);
    $logger->debug( "path: " . $path );

    my $logDir = $ENV{'LETSMTLOG_DIR'} . '/sge_jobs';
    my $workDir = $ENV{'UPLOADDIR'};

    my $jobID   = "job_" . time() . "_" . int( rand(1000000000) );
    my $jobOut  = "$logDir/$jobID.o";
    my $jobErr  = "$logDir/$jobID.e";

    mkdir $workDir if ( !-e $workDir );
    mkdir $logDir  if ( !-e $logDir );

    my $metaDB = new LetsMT::Repository::MetaManager();

    my $safe_path = LetsMT::Tools::safe_path($path);
    my $job = "source $ENV{LETSMTCONF};letsmt_run -d -u $user -p $safe_path -i $jobID;";

    #write location of stderr and stdout logfiles to metadata
    $metaDB->open();
    $metaDB->post(
        $path,
        {
            job_log_out => $jobOut,
            job_log_err => $jobErr
        }
    );
    $metaDB->close();

    #submit job
    LetsMT::Repository::Safesys::sys(
        "qsub -N $jobID -S /bin/bash -q letsmt -wd $workDir -e $jobErr -o $jobOut -b y \"$job\""
    );

    # check if job was submitted
    my $status = undef;
    check_status( message => \$status, job_id => $jobID );

    $logger->debug( 'Job status:' . $status );

    if ($status) {
        #write meta data
        $metaDB->open();
        $metaDB->post(
            $path, {
                job_status => 'submitted to grid engine with status: ' . $status,
                job_id     => $jobID,
            }
        );
        $metaDB->close();
    }
    else {
        raise( 8, 'could not submit job to grid engine' );
    }

    #write status of submit and job ID back to result reference
    $$message = "submitted job with ID '$jobID'";

    return 1;
}


=head2 C<check_status>

 $status = LetsMT::Repository::JobManager::check_status ( job_id => $jobID, path => $path )

Returns the current status of a job

Returns: true or false

=cut

sub check_status {
    my %args = @_;

    my $message = $args{message};
    my $jobID   = $args{job_id};

    #get jobID from meta data via path/url if path is set
    if ( $args{path} ) {
        $jobID = get_ID_from_path( $args{path} );
    }

    #if jobID was set or could be found in mete data
    if ($jobID) {

        my $statusXML = undef;

        #query for status of the job
        open( STATUS_XML, "qstat -xml -u $ENV{LETSMTUSER} |" )
            or raise( 8, "Can't run program: $!\n" );
        while (<STATUS_XML>) {
            $statusXML .= $_;
        }
        close(STATUS_XML);

        #parse XML status
        if ($statusXML) {
            my $parser = new XML::LibXML;
            my $doc    = $parser->parse_string($statusXML);

            my $status = $doc->findvalue(
                '//job_list[JB_name="' . $jobID . '"]/@state'
            );

            #if status string found, return it
            if ($status) {
                $$message = $status;
                return 1;
            }
            else {
                $$message = "no job with ID '$jobID' found";
                return 0;
            }
        }

        $$message = 'could not get status xml from qstat';
        return 0;
    }
    else {
        $$message = 'job ID not given or found in meta data';
        return 0;
    }
}


=head2 C<delete>

 LetsMT::Repository::JobManager::delete (job_id => $jobID, path => $path)

Delete a job, identified by its job ID or the path to the job file, from the grid engine.

Returns: true or false

=cut

sub delete {
    my %args = @_;

    my $message = $args{message};
    my $jobID   = $args{job_id};

    #get jobID from meta data via path/url if set
    if ( $args{path} ) {
        $jobID = get_ID_from_path( $args{path} );
    }

    #if jobID was set or could be found in mete data
    if ($jobID) {
        my $status = undef;

        #try to delete job
        open( STATUS, "qdel $jobID |" ) or raise( 8, "Can't run program: $!\n" );
        while (<STATUS>) {
            $status .= $_;
        }
        close(STATUS);

        #TODO: delete also meta data and old log files!

        get_logger(__PACKAGE__)->debug( 'Status:' . $status );

        if ($status) {
            $$message = $status;
        }
    }
}


=head2 C<get_ID_from_path>

 $id = LetsMT::Repository::JobManager::get_ID_from_path ($path)

Returns the job ID if it is found at the given path

Returns: jobID string

=cut

sub get_ID_from_path {
    my $pathref = shift;
    my $path = join( '/', @{$pathref} );

    my $metaDB = new LetsMT::Repository::MetaManager();
    $metaDB->open();
    my $search_result = $metaDB->get( $path, 'job_id' );
    $metaDB->close();
    unless ($search_result) {
        raise( 11, 'no jobID found in meta data at this path' );
    }

    return $search_result;
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