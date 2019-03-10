package LetsMT::Repository::JobManager;

=head1 NAME

LetsMT::Repository::JobManager - manager for the job API

=head1 DESCRIPTION

=cut

use strict;

use open qw(:std :utf8);
use utf8;

use XML::LibXML;
use File::Basename;
use File::Temp qw/tempfile tempdir/;
use File::Path;
use Encode qw(decode decode_utf8 is_utf8);
use MIME::Lite;
use POSIX qw(strftime);
use DBM_Filter;
use DB_File;



use LetsMT::Repository::MetaManager;
use LetsMT::Resource;
use LetsMT::WebService;
use LetsMT::Tools;
use LetsMT::Repository::Safesys;
use LetsMT::Corpus;
use LetsMT::Align;
use LetsMT::Align::Words;
use LetsMT::Align::Documents;
use LetsMT::Tools::UD;
use LetsMT::Export::Reader;
use LetsMT::Export::Writer;
use LetsMT::Export::Reader::XML;
use LetsMT::Export::Writer::XML;
use LetsMT::DataProcessing::Tokenizer;

use Cwd;
use Data::Dumper;
use Digest::MD5::File qw/dir_md5_hex file_md5_hex/;
use LetsMT::Repository::Err;
use Log::Log4perl qw(get_logger :levels);


## make sure that Digest::MD5 does not croak on weird file names
## PROBLEM: this will ignore files with utf8 characters
$Digest::MD5::File::NOFATALS = 1;

## this does not help (it refers to reading file contents)
# $Digest::MD5::File::UTF8 = 1;




## wget parameters
##
## WgetReject: file types to reject
## WgetQuota:  overall download quota (0=unlimited)
##
## TODO: make it possible to adjust parameters from API calls
##       other kind of checks to make sure we only download files we want

my $WgetReject = 'zip,mp3,mp4,tar,gz,jpg,tiff,gif,png,mov,m4v,css,rar,js,pl,sh,rb,ico';
my $WgetQuota = '0';
# my $WgetQuota = '4000m';


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
    my $walltime = $args{'walltime'} || 4320;
    my $queue    = $args{'queue'}    || 'standard';

    push my @cmd_array, map { { "command" => $_ } } $commands;

    # Build hash structure for XML job description
    my $hash_structure = {
        'wallTime' => [ $walltime ],
        'queue'    => [ $queue ],
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
    # binmode( $fh, ':encoding(utf8)' );

    ## let's do some crazy decoding / encoding instead ....
    utf8::decode($xml);
    utf8::encode($xml);

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

    ## create a new job
    my $jobfile = join( '/',
			'storage', $slot, $branch,
			'jobs', 'run', @{$path_elements}
    );
    $jobfile .= '.'.$command;
    $jobfile .= '.xml';

    my $relative_path = join('/',@{$path_elements});

    my $argstr = '';
    foreach (keys %{$args}) {
        next if ($_ eq 'run');
        $argstr .=
            ' ' . &safe_path( $_ ) .
            ' ' . &safe_path( $args->{$_} );
    }

    my $queue    = $args->{queue} || 'standard';
    my $walltime = $args->{walltime} || 4320;

    # create job
    create_job(
        path     => $jobfile,
        uid      => $args->{uid},
        walltime => $walltime,
        queue    => $queue,
        commands => [
            'letsmt_make'
            . ' -u ' . &safe_path( $args->{uid} )
            . ' -s ' . &safe_path( $slot )
            . ' -p ' . &safe_path( $relative_path )
            . ' '    . &safe_path( $command )
            . $argstr
        ]
    );

    # and submit job
    my $message;
    my $jobID = &submit(
        message  => \$message,
        path     => $jobfile,
        uid      => $args->{uid},
	queue    => $queue,
	walltime => $walltime,
	);

    ## save job ID also for the resource
    my $path = join( '/', $slot, $branch, @{$path_elements} );
    my $metaDB = new LetsMT::Repository::MetaManager();
    $metaDB->open();
    $metaDB->post( $path, { job_id => $jobID } );
    $metaDB->close();

    return wantarray ? ($jobfile, $jobID) : $jobfile;
}



=head2 C<submit_job>

 LetsMT::Repository::JobManager::submit_job (
    $command,
    $path_elements,
    $args
 )

Submit jobs (running $command) for resources in the given path to the batch job server.

=cut

## align|align_candidates|realign|import|reimport|.*_ida|.*_isa

sub submit_job {

    if ($_[0]=~/^(align|align_candidates|realign|import|reimport|.*_ida|.*_isa)$/){
	return run(@_);
    }
    if (my $jobfile = job_maker(@_) ){
	return "job maker submitted ($jobfile)";
    }
    return "failed to submit job maker!";
}


## OLD: job_maker only in selected cases
## NEW: job_maker is default and selected cases run directly (see above)
##
#     if ($_[0]=~/^(detect_translations|detect_unaligned|parse|wordalign|make_tmx|download|crawl)$/){
# 	if (my $jobfile = job_maker(@_) ){
# 	    return "job maker submitted ($jobfile)";
# 	}
# 	return "failed to submit job maker!";
#     }
#     return run(@_);
# }




=head2 C<run>

 LetsMT::Repository::JobManager::run (
    $command,
    $path_elements,
    $args
 )

Run jobs (running $command) for resources in the given path with given arguments $args.
Some commands create jobs that will be submitted to the batch job server: align, realign, import, reimport, align_candidates
Other commands are directly executed on the system.

=cut

sub run {
    my ($command,$path_elements,$args) = @_;

    if ($command eq 'align'){
        return run_align($path_elements, $args);
    }
    if ($command eq 'detect_and_align'){
        return run_detect_and_align($path_elements, $args);
    }
    if ($command eq 'detect_and_align_unaligned'){
        return run_detect_and_align($path_elements, $args, 1);
    }
    if ($command eq 'detect_translations'){
        return run_detect_translations($path_elements, $args);
    }
    if ($command eq 'detect_unaligned'){
        return run_detect_translations($path_elements, $args, 1);
    }
    if ($command eq 'align_candidates'){
        return run_align_candidates($path_elements, $args);
    }
    if ($command eq 'realign'){
        return run_realign($path_elements, $args);
    }
    if ($command eq 'find_language_links'){
        return run_find_language_links($path_elements, $args);
    }
    if ($command eq 'import'){
        return run_import($path_elements, $args);
    }
    ## activate overwriting 
    if ($command eq 'reimport'){
        return run_import($path_elements, $args, 1);
    }
    if ($command eq 'tokenize'){
        return run_tokenize($path_elements, $args);
    }
    if ($command eq 'wordalign'){
        return run_wordalign($path_elements, $args);
    }
    if ($command eq 'parse'){
        return run_parse($path_elements, $args);
    }
    if ($command eq 'make_tmx'){
        return run_make_tmx($path_elements, $args);
    }
    if ($command eq 'download'){
        return run_import_url($path_elements, $args);
    }
    ## TODO: implement web crawling of entire websites
    ##       (using bitextor?)
    ## 
    if ($command eq 'crawl'){
        return run_crawler($path_elements, $args);
    }
    if ($command eq 'setup_isa'){
        return run_setup_isa($path_elements, $args);
    }
    if ($command eq 'setup_ida'){
        return run_setup_ida($path_elements, $args);
    }
    if ($command eq 'upload_isa'){
        return run_upload_isa($path_elements, $args);
    }
    if ($command eq 'remove_isa'){
        return run_remove_isa($path_elements, $args);
    }
    return 0;
}



## combine detect parallel documents and their alignment

sub run_detect_and_align {
    if (&run_detect_translations(@_)){
	return &run_align_candidates(@_);
    }
    return 0;
}


=head2 C<run_detect_translations>

 LetsMT::Repository::JobManager::run_detect_translations (
    $path_elements,
    $args,
    $skip_aligned
 )

Try to find parallel documents and store them as align-candidates
in the metadata of the source corpus files. If skip_aligned is on than
the system will skip those files that are already aligned.

=cut

sub run_detect_translations {
    my $path_elements = shift;
    my $args = shift || {};
    my $skip_aligned = shift || 0;

    my @path      = @{$path_elements};
    my $slot      = shift(@path);
    my $branch    = shift(@path);

    my $corpus    = LetsMT::Resource::make( $slot, $branch );
    my $resource  = @path
        ? LetsMT::Resource::make(
            $slot, $branch, join( '/', @path )
        )
        : $corpus;


    my @ResList = ( );
    if ( resource_type($resource) eq 'corpusfile' ){
	@ResList = ( $resource );
    }
    ## find all resources in a subtree if resource is not an XML file
    elsif ( $#{$path_elements} ){
	@ResList = &find_corpusfiles( $resource );
    }

    # my %parallel = &find_parallel_resources($corpus,\@resources,%{$args});
    # my %parallel = &find_parallel_resources($corpus,\@resources);
    my %parallel = &find_translations( $corpus, \@ResList, %{$args} );

    # hash of candidates for each resource
    my %candidates = ();
    my %resources  = ();

    my $count = 0;
    foreach my $src (sort keys %parallel) {

	next unless (keys %{$parallel{$src}});
	my $SrcRes = LetsMT::Resource::make_from_storage_path($src);
	my $SrcPath = $SrcRes->path;

	## if skip_aligned: get all aligned files to skip those
	my @aligned = ();
	my %alignedLang = ();
	if ($skip_aligned){
	    my $response  = LetsMT::WebService::get_meta( $SrcRes );
	    $response     = decode( 'utf8', $response );
	    my $XmlParser = new XML::LibXML;
	    my $dom       = $XmlParser->parse_string( $response );
	    my @nodes     = $dom->findnodes('//list/entry');
	    @aligned      = split( /,/, $nodes[0]->findvalue('aligned_with') );
	    foreach (@aligned){
		my @parts = split(/\//);
		shift(@parts);               # shift away 'xml'
		my $trglang = shift(@parts); # lang of aligned document
		$alignedLang{$trglang} = $_; # one aligned doc per lang!
	    }
	}

        foreach my $trg (sort keys %{$parallel{$src}}) {
	    my $TrgRes = LetsMT::Resource::make_from_storage_path($trg);
	    my $TrgPath = $TrgRes->path;

	    ## OLD: skip only if the SAME document is aligned already
	    ## skip if we the files is already in the list of aligned resources
            # next if ( grep ( $TrgPath eq $_, @aligned ) );

	    ## NEW: skip if the language is aligned already!
	    my @parts = split(/\//,$TrgPath);
	    next if ( exists($alignedLang{$parts[1]}) );

	    ## skip the other translation direction
            if (exists $parallel{$trg}) {
		delete $parallel{$trg}{$src};
	    }
	    $candidates{$SrcPath}{$TrgPath}++;
	    $resources{$SrcPath} = $SrcRes;
	    $count++;
	}
    }
    foreach my $src ( keys %candidates ){
	my $trg = join( ',', sort keys %{$candidates{$src}} );
        &LetsMT::WebService::put_meta(
	    $resources{$src},
	    'align-candidates' => $trg );
    }
    return $count;
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

    my @path      = @{$path_elements};
    my $slot      = shift(@path);
    my $branch    = shift(@path);

    my $corpus    = LetsMT::Resource::make( $slot, $branch );
    my $resource  = @path
        ? LetsMT::Resource::make(
            $slot, $branch, join( '/', @path )
        )
        : $corpus;

    ## conversion magic if the file is a TMX resource
    $resource->base_path('xml') if ($resource->base_path eq 'tmx');

    ## if trg argument is given: assume that we have two 
    ## given resources to be aligned (in the same slot/branch)

    if ($resource && (exists $$args{trg}) ){
	my $SrcRes = $resource;
	my $TrgRes = LetsMT::Resource::make( $slot, $branch, $$args{trg} );
	my $AlgRes = LetsMT::Align::make_align_resource($SrcRes, $TrgRes);
	# delete($$args{trg});

	return &run_align_resource(
	    $slot, $branch,
	    $SrcRes->path(), $TrgRes->path(),
	    $AlgRes->path(),
	    $args
            );
    }

    ## find all resources in a subtree if resource is not an XML file
    my @resources = ( $resource );
    if ($resource->type ne 'xml'){
	@resources = &find_corpusfiles( $resource );
    }

    ## otherwise: look for parallel resources and align all of them
    ## NOTE: this may create lots of align jobs!
    # my %parallel = &find_parallel_resources($corpus,\@resources,%{$args});
    # my %parallel = &find_parallel_resources($corpus,\@resources);
    my %parallel = &find_translations($corpus,\@resources, %{$args});

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



=head2 C<run_align_candidates>

 LetsMT::Repository::JobManager::run_align_candidates (
    $path_elements,
    $args
 )

Align documents that have been identified as parallel documents by the name matching heuristics.
Those candidates are stored in the metadata.

=cut

sub run_align_candidates {
    my $path_elements = shift;
    my $args = shift || {};

    my @sentalign = ();

    my @path      = @{$path_elements};
    my $slot      = shift(@path);
    my $branch    = shift(@path);

    my $corpus    = LetsMT::Resource::make( $slot, $branch );
    my $resource  = @path
        ? LetsMT::Resource::make(
            $slot, $branch, join( '/', @path )
        )
        : $corpus;

    ## check whether there is metadata for the resource
    my $response = LetsMT::WebService::get_meta( $resource );
    $response = decode( 'utf8', $response );

    my $XmlParser = new XML::LibXML;
    my $dom       = $XmlParser->parse_string( $response );
    my @nodes     = $dom->findnodes('//list/entry');

    ## no corpusfile found: search recursively!
    unless (@nodes && ($nodes[0]->findvalue('resource-type') eq 'corpusfile') ) {
	$response = LetsMT::WebService::get_meta(
	    $resource,
	    'ENDS_WITH_align-candidates' => 'xml',
	    type                         => 'recursive',
	    action                       => 'list_all'
	    );
	$dom   = $XmlParser->parse_string( $response );
	@nodes = $dom->findnodes('//list/entry');
    }

    my $count=0;
    foreach my $n (@nodes){
	my @candidates = split( /,/, $n->findvalue('align-candidates') );
	my @aligned    = split( /,/, $n->findvalue('aligned_with') );
        my $srcfile    = $n->findvalue('@path');
	my $SrcRes     = LetsMT::Resource::make_from_storage_path($srcfile);
	foreach my $t (@candidates){
	    my $TrgRes = LetsMT::Resource::make( $slot, $branch, $t );
            my $AlgRes = LetsMT::Align::make_align_resource($SrcRes, $TrgRes);

            &run_align_resource(
                $slot, $branch,
                $SrcRes->path(), $TrgRes->path(),
                $AlgRes->path(),
                $args
            );
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

    ## make the resource and turn it into the xces files in case it is TMX
    ## TODO: is it good to introduce this kind of conversion magic?
    my $resource = LetsMT::Resource::make_from_storage_path( $path );
    $resource->base_path('xml') if ($resource->base_path eq 'tmx');
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
    $jobfile .= '.xml';

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

    if (my ($success, $response) = 
	LetsMT::WebService::post_job( $job_resource, 'uid' => $args->{uid} )) {
        my $resource = LetsMT::Resource::make( $slot, $branch, $sentalign );
        LetsMT::WebService::post_meta(
            $resource,
            status => 'waiting in alignment queue',
            uid    => $args->{uid},
	    job_id => _get_jobid_from_status($response)
        );
        return 1;
    }
    return 0;
}



sub run_find_language_links {
    my $path_elements = shift;
    my $args = shift || {};

    my $slot      = shift(@{$path_elements});
    my $branch    = shift(@{$path_elements});

    my $resource  = LetsMT::Resource::make( $slot, $branch, join( '/', @{$path_elements} ) );
    return &find_language_links($resource, $$args{link_type} );
}


## tokenize a resource or submit jobs to tokenize all resources in a subtree

sub run_tokenize {
    my ($path_elements,$args) = @_;
    $args = {} unless $args;

    my @sentalign = ();
    my $path      = join('/',@{$path_elements});
    my $resource  = LetsMT::Resource::make_from_storage_path( $path );

    ## run word alignment if the file is a sentence alignment file
    if ($resource->type eq 'xml') {
	$$args{method} = 'europarl' unless (exists $$args{method});

	my $lang      = $resource->language;
	my $tokenizer = new LetsMT::DataProcessing::Tokenizer(
	    method => $$args{method},
	    lang   => $resource->language );
	my $reader = new LetsMT::Export::Reader::XML( tokenizer  => $tokenizer );
	my $writer = new LetsMT::Export::Writer::XML;

	my $outres = $resource->clone;
	$outres->base_path('tok');

	$reader->open($resource);
	$writer->open($outres);

	my $before = {};
	my $after  = {};
	while ( my $data = $reader->read($before,$after) ) {
	    $writer->write($data,$before,$after);
	}
	$reader->close;
	$writer->close;

	my %para = ();
	$para{auto_commit} = $$args{auto_commit} if (defined $$args{auto_commit});
	if ( &LetsMT::WebService::put_resource( $outres, %para ) ){
	    &LetsMT::WebService::put_meta( $resource,
					   'tokenized' => $outres->path );
	    return $outres;
	}
    }

    ## search for all sentence alignment files and submit wordalign jobs
    my @resources = &find_corpusfiles( $resource );
    foreach my $res (@resources){
	my @path_elements = split(/\/+/,$res->storage_path);
	&job_maker( 'tokenize', \@path_elements, $args );
    }
    return scalar @resources;
}



## parse a resource or submit jobs to parse all resources in a subtree

sub run_parse {
    my ($path_elements,$args) = @_;
    $args = {} unless $args;

    my @sentalign = ();
    my $path      = join('/',@{$path_elements});
    my $resource  = LetsMT::Resource::make_from_storage_path( $path );

    ## run word alignment if the file is a sentence alignment file
    if ($resource->type eq 'xml') {
	my $udpipe = new LetsMT::DataProcessing::UDPipe;
	my $lang = $resource->language();
	if ($udpipe->load_model($lang)){
	    unless (-e $resource->local_path){
		my $tmpdir = $ENV{LETSMT_TMP} || '/tmp';
		my $local_root = tempdir( 'parse_XXXXXXXX',
					  DIR     => $tmpdir,
					  CLEANUP => 1 );
		$resource->local_dir($local_root);
		unless ( &LetsMT::WebService::get_resource($resource) ) {
		    get_logger(__PACKAGE__)->error("Unable to fetch resource: $resource");
		}
	    }
	    my $pr = $resource->clone();
	    $pr->base_path('ud');

	    my $input  = $resource->local_path;
	    my $output = $pr->local_path;
	    my $outdir = dirname($output);

	    print "parsing: ".$resource->path."\n";
	    &run_cmd( 'mkdir', '-p', $outdir );
	    $udpipe->parse_xml_file($input,$output);
	    my %para = ();
	    $para{auto_commit} = $$args{auto_commit} if (defined $$args{auto_commit});
	    if ( &LetsMT::WebService::put_resource( $pr, %para ) ){
		&LetsMT::WebService::put_meta( $resource,'parsed' => $pr->path );
		return $pr;
	    }
	}
	return undef;
    }

    ## search for all sentence alignment files and submit wordalign jobs
    my @resources = &find_corpusfiles( $resource );
    foreach my $res (@resources){
	my @path_elements = split(/\/+/,$res->storage_path);
	&job_maker( 'parse', \@path_elements, $args );
    }
    return scalar @resources;
}


sub run_wordalign {
    my ($path_elements,$args) = @_;
    $args = {} unless $args;

    my @sentalign = ();
    my $path      = join('/',@{$path_elements});
    my $resource  = LetsMT::Resource::make_from_storage_path( $path );

    ## conversion magic if the file is a TMX resource
    $resource->base_path('xml') if ($resource->base_path eq 'tmx');

    ## run word alignment if the file is a sentence alignment file
    if ($resource->type eq 'xces') {

	## check whether the source and target files exist as 
	## UD parsed or tokenized versions
	## if not? Try to parse or tokenize it ...
	my $files = LetsMT::Corpus::find_sentence_aligned($resource);
	return unless (ref($files) eq 'HASH');
	return unless (keys %{$files});
	my ($srcdoc) = keys %{$files};
	my ($trgdoc) = keys %{$$files{$srcdoc}};

	my $srcres = LetsMT::Resource::make_from_storage_path($srcdoc);
	my $trgres = LetsMT::Resource::make_from_storage_path($trgdoc);

	foreach my $res ($srcres, $trgres){
	    $res->base_path('ud');
	    unless (LetsMT::Corpus::resource_exists($res)){
		$srcres->base_path('tok');
		unless (LetsMT::Corpus::resource_exists($res)){
		    $res->base_path('xml');
		    my @path = split(/\/+/,$res->storage_path);
		    print "pre-process: ".$res->path."\n";
		    unless (run_parse(\@path)){
			unless (run_tokenize(\@path)){
			    return 0;
			}
		    }
		}
	    }
	}

	print "word-align: ".$resource->path."\n";
	my $aligner = new LetsMT::Align::Words;
	my @newres = $aligner->wordalign($resource);
	my %para = ();
	$para{auto_commit} = $$args{auto_commit} if (defined $$args{auto_commit});
	foreach my $n (@newres){
	    &LetsMT::WebService::put_resource( $n, %para )
	}
	if (@newres){
	    &LetsMT::WebService::put_meta( $resource,
					   'wordaligned'     => $newres[0]->path,
					   'wordaligned_ids' => $newres[1]->path );
	}
	return @newres;
    }

    ## search for all sentence alignment files and submit wordalign jobs
    my $files = &find_sentence_aligned( $resource, $args );

    my $count = 0;
    my %done = ();
    foreach my $s (keys %{$files}){
        foreach my $t (keys %{$$files{$s}}){
            next if ($done{$$files{$s}{$t}});
	    my @path_elements = split(/\/+/,$$files{$s}{$t});
	    &job_maker( 'wordalign', \@path_elements, $args );
            $done{ $$files{$s}{$t} } = 1;
            $count++;
        }
    }
    return $count;
}


## convert bitexts to TMX

sub run_make_tmx {
    my ($path_elements,$args) = @_;
    $args = {} unless $args;

    my @sentalign = ();
    my $path      = join('/',@{$path_elements});
    my $resource  = LetsMT::Resource::make_from_storage_path( $path );

    ## special case: root xml dir!
    ## --> make one tmx for all bitexts in the corpus
    if ($resource->path eq 'xml'){
	my $slot      = $$path_elements[0];
	my $branch    = $$path_elements[1];
	my $corpus    = LetsMT::Resource::make( $slot, $branch );
	my $response  = LetsMT::WebService::get_meta( $corpus );
	my $XmlParser = new XML::LibXML;
	my $dom       = $XmlParser->parse_string( $response );
	my @nodes     = $dom->findnodes('//list/entry');

	return undef unless (@nodes);

	my @pairs     = split(/,/,$nodes[0]->findvalue('parallel-langs'));
	my $count     = 0;
	foreach my $p (@pairs){
	    my @bitext = @{$path_elements};
	    push(@bitext,$p);
	    if (&run_make_tmx(\@bitext,$args)){ $count++; }
	}
	return $count;
    }


#     if ($resource->type eq 'xces') {

    print "convert to TMX: ".$resource->path."\n";

    ## fetch resource if necessary
    unless (-e $resource->local_path){
	my $tmpdir = $ENV{LETSMT_TMP} || '/tmp';
	my $local_root = tempdir( 'make_tmx_XXXXXXXX',
				  DIR     => $tmpdir,
				  CLEANUP => 1 );
	$resource->local_dir($local_root);
	unless ( &LetsMT::WebService::get_resource($resource) ) {
	    get_logger(__PACKAGE__)->error("Unable to fetch resource: $resource");
	}
    }

    ## output resource and output writer
    ## if the file is a single xces file: create standard TMX file
    ## if the file is a durectory: create a TMX with unique entries (no duplicates)
    my $outres = undef;
    my $output = undef;
    my $input = undef;
    if ($resource->type ne 'xces') {
	## TODO: download_all_mono avoids downloading all monolingual files one-by-one
	##       but that's quite a waste if only a small portion of the monolingual files
	##       are aligned. So, better leave it out at the moment ....
	## TODO: adding the option "download_all_mono" does not seem to work either
	##       --> the mono files do not appear in the correct tmp location ....
	# $input = new LetsMT::Export::Reader( $resource, $resource->type, 
	# 				     download_all_mono => 1 );
	$input = new LetsMT::Export::Reader( $resource, $resource->type );
	$outres = $resource->graft_suffix('.tmx');
	$output = new LetsMT::Export::Writer( $outres, 'tmx_unique' );
    }
    else{
	$input = new LetsMT::Export::Reader( $resource, $resource->type );
	$outres = $resource->clone;
	$output = new LetsMT::Export::Writer( $outres, 'tmx' );
    }
    $outres->base_path('tmx');

    return undef unless($input);
    return undef unless($output);

    ## convert the data
    $input->open($resource) || return undef;
    $output->open($outres) || return undef;
    my ($before, $after) = ({}, {});
    while ( my $data = $input->read( $before, $after ) ) {
	$output->write( $data, $before, $after );
    }
    $input->close();
    $output->close();

    ## send the TMX by e-mail if there is an email in the arguments
    if ($$args{email}=~/\S+\@\S+/){
	my $msg = MIME::Lite->new(
	    From    => 'admin@opus.nlpl.org',
	    To      => $$args{email},
	    Subject => 'TMX files generated by OPUS',
	    Data    => "The TMX file is attached.\n\nOPUS repository\n\n"
	    );
	$msg->attach(
	    Path    => $outres->local_path,
	    Type    =>'AUTO'
	    );
	$msg->send;
    }

    my %para = ();
    $para{auto_commit} = $$args{auto_commit} if (defined $$args{auto_commit});
    if ( &LetsMT::WebService::put_resource( $outres, %para ) ){
	&LetsMT::WebService::put_meta( $resource,'tmx' => $outres->path );
	return $outres;
    }
    return undef;


    ## NEW: don't make individual jobs for each sentence alignment file
    ##      but create one TMX file for all of them

    # }

    # ## search for all sentence alignment files and submit conversion jobs
    # my $files = &find_sentence_aligned( $resource, $args );

    # my $count = 0;
    # my %done = ();
    # foreach my $s (keys %{$files}){
    #     foreach my $t (keys %{$$files{$s}}){
    #         next if ($done{$$files{$s}{$t}});
    # 	    my @path_elements = split(/\/+/,$$files{$s}{$t});
    # 	    &job_maker( 'make_tmx', \@path_elements, $args );
    #         $done{ $$files{$s}{$t} } = 1;
    #         $count++;
    #     }
    # }
    # return $count;
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
    my ($path_elements,$args,$overwrite) = @_;

    my @documents = ();
    my $path      = join('/',@{$path_elements});


    my $resource = LetsMT::Resource::make_from_storage_path($path);
    if (is_file($resource)){
        push(@documents,$path);
    }
    else{
	# create a new importer object for type checking
	# --> check if a certain file type can be handled by the import module!
	# --> we only use suffix-based lookups to avoid importing logfiles etc
	# 
	# (set 'local_root' to avoid creating temp-files)
	my $importer = new LetsMT::Import(local_root => '/tmp');
        my @files    = &find_resources($resource,$args);

        foreach my $p (@files){
            if ($importer->suffix_lookup($p)){
                push(@documents,$p);
            }
        }
    }

    my $count=0;
    foreach my $s (@documents){
        run_import_resource($s,$args,$overwrite);
        $count++;
    }
    return $count;
}



sub run_import_url{
    # my ($path_elements, $args) = @_;
    my $path_elements = ref($_[0]) eq 'ARRAY' ? shift : [];
    my $args          = ref($_[0]) eq 'HASH'  ? shift : ();

    raise( 12, "slot/branch", 'warn')   unless (@{$path_elements} > 1);
    raise( 12, "parameter url", 'warn') unless (exists $args->{url});
    raise( 17, "protocol (supported = http|https|ftp)", 'warn' ) 
	unless ($args->{url}=~/^(http|https|ftp):\/\/(.*)$/);

    my $doc    = $2;
    my $slot   = shift(@{$path_elements});
    my $branch = shift(@{$path_elements});

    unless (@{$path_elements}){
	## remove all attributes and special characters
	$doc=~s/\?.*$$//;
	$doc=~s/[^a-zA-Z0-9\/_\-\.\s]//g;
	$doc=~s/\/+$//;
	push(@{$path_elements},'uploads','url',$doc);
    }

    ## make the storage request to download the page
    my $resource = LetsMT::Resource::make($slot,$branch,join('/',@{$path_elements}));
    delete $args->{run};
    return LetsMT::WebService::put( $resource, %{$args} );
}



## recursively download a whole website ...
## TODO: make sure that this does not crash the system and overloads another server
sub run_crawler{
    # my ($path_elements, $args) = @_;
    my $path_elements = ref($_[0]) eq 'ARRAY' ? shift : [];
    my $args          = ref($_[0]) eq 'HASH'  ? shift : ();

    ## NEW: ignore all path elements
    # raise( 12, "slot/branch", 'warn')   unless (@{$path_elements} > 1);
    raise( 12, "parameter uid", 'warn') unless (exists $args->{uid});
    raise( 12, "parameter url", 'warn') unless (exists $args->{url});
    # raise( 17, "protocol (supported = http|https|ftp)", 'warn' ) 
    # 	unless ($args->{url}=~/^(http|https|ftp):\/\/(.*)$/);
    raise( 17, "URL (supported = http|https|ftp)", 'warn' ) 
	unless ($args->{url}=~/^(http|https|ftp):\/\/([a-zA-Z0-9][a-zA-Z0-9\.\-]*[a-zA-Z0-9])(\/[\~a-zA-Z0-9\.\-\/]*)?$/i);

    ## select long queue as the default
    $$args{queue} = 'long' unless ($$args{queue});

    my $domain = $2;
    my $doc    = $domain;
    my $slot   = shift(@{$path_elements});
    my $branch = shift(@{$path_elements});

    ## make the upload location if not given
    unless (@{$path_elements}){
	## remove all attributes and special characters
	$doc=~s/\?.*$$//;
	$doc=~s/[^a-zA-Z0-9\/_\-\.\s]//g;
	$doc=~s/\/+$//;
	push(@{$path_elements},$doc);	
    }
    unshift(@{$path_elements},'uploads') unless ($$path_elements[0] eq 'uploads');

    ## temporary download space
    my $tmphome = $ENV{LETSMT_TMP} || '/tmp';
    my $tmpdir  = tempdir( 'crawl_XXXXXXXX',
			   DIR     => $tmphome,
			   CLEANUP => 1 );

    ## add rejected file formats (file extensions)
    if (exists $$args{reject}){
	$WgetReject .= ','.$$args{reject};
    }

    ## download quota
    my $quota = exists $$args{quota} ? $$args{quota} : $WgetQuota;

    ## TODO: restrict-file-names mode "nocontrol" might be too difficult
    ##       (see man pages to see what that means)
    ## other options: unix (that should be the default), ascii, lowercase, ...
    ##
    ## TODO: --content-disposition is experimental (is it stable enough for us?)

    ## wget parameters
    my @para = ('-r','--no-parent',
		'--convert-links',
		'--adjust-extension',
		'--restrict-file-names=nocontrol',
		'--content-disposition',
		'--reject',$WgetReject,
		# '--accept','xml,html,doc,pdf,docx,epub,rtf,srt,txt,php',
		'--ignore-case',
		'-Q'.$quota,
		'--wait','0.1','--random-wait');

    ## add ccepted file formats (file extensions)
    if (exists $$args{accept}){
	push (@para,'--accept',$$args{accept});
    }

    my @docdir = split(/\/+/,$doc);
    if (@docdir > 1){
	my @subdir = @docdir;
	shift(@subdir);
	push(@para,'-I',join('/',@subdir));
    }

    ## use URL domain as the slot if no slot is set
    ## use user as branch if not set
    $slot    = shift(@docdir) unless ($slot);
    $branch  = $args->{uid}   unless ($branch);

    ## make sure that the file exitension is a tar.gz file
    $$path_elements[-1]=~s/(.tar|tgz)?(.gz)?$//;
    my $tarbase = join( '/', $tmpdir, $$path_elements[-1] );
    $$path_elements[-1].='.tar.gz';
    my $tarfile = join( '/', $tmpdir, $$path_elements[-1] );

    ## download, pack into tar archive and upload to repository
    my $pwd = getcwd();
    chdir($tmpdir);

    ## TODO: run_cmd does not seem to work for this
    ##       even with the higher timeout
    ## --> use safe_system for now ...

    # ## set the run_cmd timout to 3 days
    # local $LetsMT::Tools::TIMEOUT = 3*24*60*60;
    # if (&run_cmd( 'wget', @para, $args->{url} ) ){
    # 	if (&run_cmd('tar', '-czf', $tarfile, '-C', $slot, './')){

    print STDERR "run wget:\n";
    print STDERR join(' ', 'wget', @para, $args->{url} );
    print STDERR "\n";

    unless (&safe_system( 'wget', @para, $args->{url} ) ){
	print STDERR "something went wrong with crawling - maybe timeout?\n";
    }

    ## try to save all data anyway even if wget stopped above
    if (-d $domain){

	# create and save md5 signatures to detect identical files
	# --> avoid uploading the same file again

	# my $md5file = $tarbase.'.md5';
	$$path_elements[-1] = basename($tarbase).'.md5';
	my $md5resource = LetsMT::Resource::make($slot,$branch,
						 join('/',@{$path_elements}));

	my $md5file = $md5resource->local_path();

	## TODO: should also get MD5 signatures from files in other
	##       subdirectories .... (see find and split below)
	## NEW: use our own recursive call to file_md5_hex
	##      --> properly read utf8 file names
	# my $md5hash = dir_md5_hex($domain);
	my $md5hash = _recursive_md5_hex($domain);
	unless (ref($md5hash) eq 'HASH'){
	    print STDERR "crawler: no files found when making md5 signatures!";
	    $md5hash = {};
	}
	my %md5db = ();

	## check whether there is an md5 file in the repository
	## --> download and read that file
	## --> delete all files that have the same md5 hash key

	if (LetsMT::Corpus::resource_exists($md5resource)){
	    &LetsMT::WebService::get_resource($md5resource, 'archive' => 'no');
	}
	else{
	    $md5file = basename($md5file);
	    open F,">",$md5file; close F;
	}
	my $db = tie %md5db,"DB_File",$md5file;

	$db->Filter_Key_Push('utf8');
	$db->Filter_Value_Push('utf8');

	while (my @v = each %md5db){
	    my ($file,$md5) = @v;
	    if (exists($$md5hash{$file}) && -e $domain.'/'.$file){
		if ( $$md5hash{$file} eq $md5 ){
		    print STDERR "identical MD5: delete $domain/$file\n";
		    unlink($domain.'/'.$file);
		}
		## TODO: what do we do if the file has changed?
		## --> now no change and we will overwrite the old one!
		## --> should we rename the file instead?
		else{
		    print STDERR "new MD5: overwrite $domain/$file\n";
		}
	    }
	}

	## save all MD5 signatures to file
	foreach (keys %{$md5hash}){
	    $md5db{$_} = $$md5hash{$_} if ($$md5hash{$_});
	}
	if (keys %md5db){
	    undef $db;
	    untie %md5db;
	    &LetsMT::WebService::put_file( $md5resource, $md5file );
	}

	# get local time (for tarbase)
	my $datestr = strftime "%Y-%b-%d", localtime;
	my $splitbase = $tarbase.$datestr.'_';

	my $success = 0;
	eval {
	    ## TODO: does this help with UTF8 file names?
	    local $ENV{LC_ALL} = 'en_US.UTF-8';

	    ## NEW: split into chunks of max 5000 files
	    ## NEW NEW: also allow other sub-dirs than the domain dir only
	    # &safe_system('find', $domain, '-type', 'f', '|', 'split', '-l', 5000, '-', $splitbase) ||
	    &safe_system('find', '.', '-mindepth', '2', '-type', 'f', '|', 
			 'split', '-l', 5000, '-', $splitbase) ||
			     raise( 8, "cannot download $args->{url} ($?)", 'error' );

	    ## compress each chunk of files into an archive and upload it
	    my @chunks  = glob("${splitbase}??");
	    foreach my $c (@chunks){
		my $tarfile = "$c.tar.gz";
		if ( &safe_system('tar','--ignore-failed-read','-czf',$tarfile, 
				  '-T',$c,'--transform',"s#^./${domain}/##") ){
		    # if ( &safe_system('tar','--ignore-failed-read','-czf',$tarfile, 
		    #                   '-T',$c,'--transform',"s#^${domain}/##") ){
		    $$path_elements[-1] = basename($tarfile);
		    my $resource = LetsMT::Resource::make($slot,$branch,
							  join('/',@{$path_elements}));
		    delete $args->{run};
		    delete $args->{url};
		    ## try 10 times to upload the file
		    ## (just in case it fails and we do not want to waste the crawled data)
		    foreach (0..9){
			## switch off auto-alignment to avoid racing issues if several 
			## imports run in parallel
			## TODO: maybe it's OK anyway ... leave it for now as it is
			## 
			# LetsMT::WebService::post_meta( $resource, 
			# 				   uid => $args->{uid}, 
			# 				   ImportPara_autoalign => 'off');
			if (LetsMT::WebService::put_file( $resource, $tarfile, %{$args} )){
			    $success++;
			    last;
			}
			sleep(5);
		    }
		    ## cannot upload the tar-file?
		    ## move it to a tmpfile to save from deleting
		    ## TODO: should we do that? need to inform the user/admin about it!
		    ## --> now it's at least printed to stderr ....
		    unless ($success){
			my $tmpfile = '/tmp/'.$$path_elements[-1];
			&safe_system( 'mv', $tarfile, $tmpfile );
			print STDERR "could not upload the crawled data; saved in:\n";
			print STDERR $tmpfile,"\n";
		    }
		    ## make space!
		    else{
			unlink($tarfile);
		    }
		    ## NEW: start cleaning up the directory
		    ## to make more space --> delete all files in $c
		    if (open F,'<',$c){
			binmode( F, ':encoding(utf8)' );
			while (<F>){
			    unlink($_) if (-e $_);
			}
			close F;
		    }
		}
	    }
	};
	warn $@ if $@;
	chdir($pwd);
	## if we successfully uploaded all files and automatic import is on
	## --> create a sentence alignment job 
	## TODO: this is not good either! can create racing situations!
	# if ($success){
	#     my $xmlresource = LetsMT::Resource::make( $slot,$branch,'xml' );
	#     LetsMT::WebService::put_job( $xmlresource, 
	# 				 uid => $args->{uid}, 
	# 				 run => 'align_candidates' );
	# }
	##
	## TODO: do we need to do some cleanup of $tmpdir?
	##
	return $success;
    }
    chdir($pwd);
    raise( 8, "cannot download $args->{url} ($?)", 'error' );


    # 	if (&safe_system('tar', '-czf', $tarfile, '-C', $domain, './')){
    # 	    ## make the storage request to download the page
    # 	    my $resource = LetsMT::Resource::make($slot,$branch,
    # 						  join('/',@{$path_elements}));
    # 	    delete $args->{run};
    # 	    delete $args->{url};
    # 	    chdir($pwd);
    # 	    ## try 10 times to upload the file
    # 	    ## (just in case it fails and we do not want to waste the crawled data)
    # 	    foreach (0..9){
    # 		if ( LetsMT::WebService::put_file( $resource, $tarfile, %{$args} ) ){
    # 		    return 1;
    # 		}
    # 		sleep(5);
    # 	    }
    # 	    ## cannot upload the tar-file?
    # 	    ## move it to a tmpfile to save from deleting
    # 	    my $tmpfile = '/tmp/'.$slot.'.tar.gz';
    # 	    &safe_system( 'mv', $tarfile, $tmpfile );
    # 	    print STDERR "could not upload the crawled data; saved in:\n";
    # 	    print STDERR $tmpfile,"\n";
    # 	    return 0;
    # 	}
    # }

    # chdir($pwd);
    # raise( 8, "cannot download $args->{url} ($?)", 'error' );
}


sub _recursive_md5_hex{
    my ($dir,$md5hash) = @_;

    $md5hash = {} unless (ref($md5hash) eq 'HASH');
    return {} unless (-d $dir);


    opendir( my $dh, $dir )
	or raise( 8, "cannot open dir '$dir'", 'warn' );

    ## TODO: readdir is one of the few places where utf8 decoding is really still needed
    ## http://perldoc.perl.org/perlunicode.html#When-Unicode-Does-Not-Happen
    ## TODO: utf8::all seems to be close to enabling utf8 for readdir...
    while ( my $f = decode( 'utf8', readdir $dh ) ) {
	next if ( $f =~ /^\.$/ );
	my $file = "$dir/$f";
	if ( -d $file ) {
	    _recursive_md5_hex( $file, $md5hash );
	}
	elsif ( -f $file ) {
	    ## remove first path element (key = relative path to basedir)
	    my @path = split(/\/+/,$file);
	    shift @path;
	    my $key = join('/',@path);
	    $$md5hash{$key} = file_md5_hex($file);
	}
	else{
	    print STDERR "crawler/md5: not a regular file nor a directory: $file\n";
	}
        closedir $dh;
    }
    return $md5hash;
}




=head2 C<run_import_resource>

 LetsMT::Repository::JobManager::run_import_resource (
    $path_elements,
    $args
 )

Create an import job for a resource given by its path and submit it to the SGE.

=cut

sub run_import_resource{
    my ($path,$args,$overwrite) = @_;

    # ensure $args points to a hash
    $args = {} unless (ref($args) eq 'HASH');

    my @path_elements = split(/\/+/,$path);
    my $slot = shift(@path_elements);
    my $branch = shift(@path_elements);

    # create a new import job
    my $jobfile = join('/','storage',$slot,$branch,
                           'jobs','import',@path_elements);
    $jobfile .= '.xml';

    my $relative_path = join('/',@path_elements);

    # create the job file and post it

    my $command = 
	'letsmt_import'
	. ' -u ' . &safe_path( $branch )
	. ' -s ' . &safe_path( $slot )
	. ' -p ' . &safe_path( $relative_path );
    $command .= ' -E ' . $$args{email} if (defined $$args{email});
    $command .= ' -L ' . safe_path($$args{lang}) if (defined $$args{lang});
    $command .= ' -S ' . safe_path($$args{splitter}) if (defined $$args{spitter});
    $command .= ' -T ' . safe_path($$args{tokenizer}) if (defined $$args{tokenizer});
    $command .= ' -N ' . safe_path($$args{normalizer}) if (defined $$args{normalizer});

    my $queue = $args->{queue} || 'standard';
    my $job_resource = &create_job(
        path     => $jobfile ,
        uid      => $args->{uid},
        # walltime => 5,
        queue    => $queue,
        commands => [ $command ],
    );

    # submit the new job via the JOB API

    if ( my ($success, $response) = 
	 LetsMT::WebService::post_job( $job_resource, 'uid' => $args->{uid} ) ) {

        my $corpus = LetsMT::Resource::make( $slot, $branch );
        my $res = LetsMT::Resource::make( $slot, $branch, $relative_path );
	if ($overwrite){
	    &LetsMT::WebService::post_meta(
		 $res,
		 uid                  => $args->{uid},
		 status               => 'waiting in re-import queue',
		 # import_job_id      => _get_jobid_from_status($response),
		 job_id               => _get_jobid_from_status($response),
		 imported_to          => '',
		 # import_success     => '',
		 import_failed        => '',
		 import_empty         => '',
		 import_success_count => 0,
		 import_failed_count  => 0,
		 import_empty_count   => 0);
	}
	else{
	    &LetsMT::WebService::post_meta(
		$res,
		status => 'waiting in import queue',
		job_id => _get_jobid_from_status($response),
		uid    => $args->{uid}
		);
	}
        LetsMT::WebService::del_meta(
            $corpus,
            import_failed => $relative_path,
            uid           => $args->{uid}
        );
        LetsMT::WebService::put_meta(
            $corpus,
            import_queue => $relative_path,
            uid          => $args->{uid}
        );
        return 1;
    }
    return 0;
}


## make a safe name by removing all non-ASCII characters, spaces etc

sub _safe_corpus_name{
    my $name = shift;
    $name=~s/[^a-zA-Z0-9.\-_+]/_/g;
    return $name;
}


## set up IDA for a specific corpus file

sub run_setup_ida {
    my $path_elements = shift;
    my $args = shift || {};

    return 'no valid path given' unless (ref($path_elements) eq 'ARRAY');
    return 'no sentence alignment file given' if (@{$path_elements} < 2);

    my $path       = join('/',@{$path_elements});
    my $WebRoot    = $$args{WebRoot} || '/var/www/html';
    my $IdaFileDir = $$args{IdaFileDir} || $ENV{LETSMTROOT}.'/share/ida';

    my $slot = shift(@{$path_elements});
    my $user = shift(@{$path_elements});

    my $IdaHome = join('/',$WebRoot,'ida',$user,$slot);

    ## conversion magic if the file is a TMX resource
    $$path_elements[0]='xml' if ($$path_elements[0] eq 'tmx');

    ## path should start with xml
    return 'not in xml-root of your repository' if (shift(@{$path_elements}) ne 'xml');
    my $corpus = join('_',@{$path_elements});
    $corpus-~s/\.xml$//;

    ## make a name without any special characters (basically ASCII only)
    ## TODO: save mapping to original name somewhere
    $corpus=_safe_corpus_name($corpus);

    my $CorpusHome = join('/',$IdaHome,$corpus);
    my $langpair   = shift(@{$path_elements});
    my ($src,$trg) = split(/\-/,$langpair);
    my $file       = join('/',@{$path_elements});

    return 'no valid sentence alignment file' unless ($src && $trg && $file);

    if (! -d $CorpusHome){
	File::Path::make_path($CorpusHome);

	my $resource = LetsMT::Resource::make_from_storage_path( $path, $CorpusHome );
	return "no resource" unless ($resource);

	## check whether a wordalign resource of sent align indeces exists
	my $algres = $resource->clone();
	$algres->base_path('wordalign');
	if (LetsMT::Corpus::resource_exists($algres)){
	    $resource = $algres;
	}

	# get all sentence alignments from the bitext
	&LetsMT::WebService::get_resource($resource, 'archive' => 'no') || return undef;
	open F,"<",$resource->local_path() || return "cannot read resource";
	open O,">$CorpusHome/corpus.$src-$trg" || return "cannot write link file";
	my $srcdoc = undef;
	my $trgdoc = undef;
	my @links = ();
	while (<F>){
	    chomp;
	    if (/fromDoc="(wordalign\/)?([^"]+)"/){ $srcdoc = 'ud/'.$2; }
	    if (/toDoc="(wordalign\/)?([^"]+)"/){ $trgdoc = 'ud/'.$2; }
	    if (/xtargets="([^"]*)"/){ push(@links,$1); }
	    if (/xtargets="([^ ][^ ]*;[^ ][^ ]*)"/){ print O $1,"\n"; }
	}
	close F;
	close O;
	unlink($resource->local_path());

	## TODO: should check that UD files actually exist!
	## or even better: if they don't exists: accept tokenized files!
	## --> good for annotation projection later on ...

	my $srcres = LetsMT::Resource::make( $slot, $user, $srcdoc, $CorpusHome );
	my $trgres = LetsMT::Resource::make( $slot, $user, $trgdoc, $CorpusHome );

	if (LetsMT::Corpus::resource_exists($srcres)){
	    &LetsMT::WebService::get_resource($srcres, 'archive' => 'no') || return "cannot get source UD";
	    &LetsMT::Tools::UD::deprel2db($srcres->local_path(), "$CorpusHome/corpus.$src.db");
	    unlink($srcres->local_path());
	}
	else{
	    ## TODO: get standard XML, tokenize and convert to DB_File
	}
	if (LetsMT::Corpus::resource_exists($trgres)){
	    &LetsMT::WebService::get_resource($trgres, 'archive' => 'no') || return "cannot find target UD";
	    &LetsMT::Tools::UD::deprel2db($trgres->local_path(), "$CorpusHome/corpus.$trg.db");
	    unlink($trgres->local_path());
	}
	else{
	    ## TODO: get standard XML, tokenize and convert to DB_File
	}

	## word alignment
	my $wordalgres = $algres->strip_suffix();
	$wordalgres->base_path('wordalign');
	if (LetsMT::Corpus::resource_exists($wordalgres)){
	    &LetsMT::WebService::get_resource($wordalgres, 'archive' => 'no');
	    &LetsMT::Align::Words::alg2db($wordalgres->local_path(), \@links, "$CorpusHome/corpus.$src-$trg.db");
	    unlink($wordalgres->local_path());
	}

	## finally: create the index.php file
	open IN, "<$IdaFileDir/index.in" || return "cannot read index.in";
	open OUT, ">$CorpusHome/index.php" || return "cannot write index.php";
	while (<IN>){
	    s/%%CORPUSFILE%%/corpus/;
	    s/%%SRC%%/$src/;
	    s/%%TRG%%/$trg/;
	    print OUT $_;
	}
	close IN;
	close OUT;

	return "IDA is now available at http://$ENV{LETSMTHOST}/ida/$user/$slot/$corpus";
    }

    return 'failed to prepare IDA';
}




## set up ISA for a specific corpus file

sub run_setup_isa {
    my $path_elements = shift;
    my $args = shift || {};

    return undef unless (ref($path_elements) eq 'ARRAY');
    return undef if (@{$path_elements} < 2);

    my $WebRoot    = $$args{WebRoot} || '/var/www/html';
    my $IsaFileDir = $$args{IsaFileDir} || $ENV{LETSMTROOT}.'/share/isa';

    my $slot = shift(@{$path_elements});
    my $user = shift(@{$path_elements});

    my $IsaHome = join('/',$WebRoot,'isa',$user,$slot);

    if (! -d $IsaHome){
	system("mkdir -p $IsaHome");
	system("cp -R $IsaFileDir/* $IsaHome/");
    }

    ## conversion magic if the file is a TMX resource
    $$path_elements[0]='xml' if ($$path_elements[0] eq 'tmx');

    ## path should start with xml
    return undef if (shift(@{$path_elements}) ne 'xml');
    my $corpus = join('_',@{$path_elements});
    $corpus-~s/\.xml$//;

    ## make a name without any special characters (basically ASCII only)
    ## TODO: save mapping to original name somewhere
    $corpus=_safe_corpus_name($corpus);


    my $CorpusHome = join('/',$IsaHome,'corpora',$corpus);
    my $langpair   = shift(@{$path_elements});
    my ($src,$trg) = split(/\-/,$langpair);
    my $file       = join('/',@{$path_elements});
    $file          =~s/\.xml$//;

    return undef unless ($src && $trg && $file);

    ## TODO: this does not feel very safe!
    ## change this from calling a makefile to something else
    ## ---> this should check at least the file names to avoid any problems!


    ## TODO: this is probably not good enough.
    ## some sanity check for file names and strange symbols ...
    $file=~tr/'| $@/____/;

    if (! -d $CorpusHome){
	my $pwd = getcwd();
	chdir($IsaHome);
	system("make SLOT='$slot' USER='$user' SRCLANG='$src' TRGLANG='$trg' FILE='$file' all");
    }
    return "ISA available at http://$ENV{LETSMTHOST}/isa/$user/$slot" if (! -d $CorpusHome);
    return undef;
}


## completely remove ISA for a specific corpus file

sub run_remove_isa {
    my $path_elements = shift;
    my $args = shift || {};

    return undef unless (ref($path_elements) eq 'ARRAY');
    return undef if (@{$path_elements} < 2);

    my $WebRoot    = $$args{WebRoot} || '/var/www/html';
    my $IsaFileDir = $$args{IsaFileDir} || $ENV{LETSMTROOT}.'/share/isa';

    my $slot = shift(@{$path_elements});
    my $user = shift(@{$path_elements});

    ## conversion magic if the file is a TMX resource
    $$path_elements[0]='xml' if ($$path_elements[0] eq 'tmx');

    my $path = join('/',@{$path_elements});
    $path    =~s/\.xml$/.isa.xml/;

    return undef if (shift(@{$path_elements}) ne 'xml');

    unshift( @{$path_elements},$slot );
    my $corpus = join('_',@{$path_elements});
    $corpus=~s/\.xml$//;

    ## make a name without any special characters (basically ASCII only)
    ## TODO: save mapping to original name somewhere
    $corpus=_safe_corpus_name($corpus);


    my $IsaHome    = join('/',$WebRoot,'isa',$user,$slot);
    my $CorpusHome = join('/',$IsaHome,'corpora',$corpus);
    my $CesFile    = $CorpusHome.'.ces';

    ## uload a copy to safe the alignments
    my $resource = new LetsMT::Resource(
	slot => $slot,
	user => $user,
	path => $path,
	);

    if (-f $CesFile){
	LetsMT::WebService::put_file($resource,$CesFile);
    }

    ## dangerous: remove the whole file system tree ...
    unlink($CesFile) if (-e $CesFile);
    if (-d $CorpusHome){
	rmtree($CorpusHome);
    }
    return "'$corpus' successfully removed from $ENV{LETSMTHOST}/isa/$user/$slot";
}



## upload the sentence alignment file to the repository

sub run_upload_isa {
    my $path_elements = shift;
    my $args = shift || {};

    return undef unless (ref($path_elements) eq 'ARRAY');
    return undef if (@{$path_elements} < 2);

    my $WebRoot    = $$args{WebRoot} || '/var/www/html';
    my $IsaFileDir = $$args{IsaFileDir} || $ENV{LETSMTROOT}.'/share/isa';

    my $slot = shift(@{$path_elements});
    my $user = shift(@{$path_elements});

    ## conversion magic if the file is a TMX resource
    $$path_elements[0]='xml' if ($$path_elements[0] eq 'tmx');

    my $path = join('/',@{$path_elements});

    return undef if (shift(@{$path_elements}) ne 'xml');

    unshift( @{$path_elements},$slot );
    my $corpus = join('_',@{$path_elements});
    $corpus=~s/\.xml$//;

    ## make a name without any special characters (basically ASCII only)
    ## TODO: save mapping to original name somewhere
    $corpus=_safe_corpus_name($corpus);


    my $IsaHome    = join('/',$WebRoot,'isa',$user,$slot);
    my $CorpusHome = join('/',$IsaHome,'corpora',$corpus);
    my $cesfile    = $CorpusHome.'.ces';

    my $resource = new LetsMT::Resource(
	slot => $slot,
	user => $user,
	path => $path,
	);

    return undef unless (-f $cesfile);
    if (LetsMT::WebService::put_file($resource,$cesfile)){
	return "successfully uploaded ISA alignment file to ".$resource->storage_path;
    }
    return "failed to upload ISA alignment file to ".$resource->storage_path;
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

    my $logDir = $ENV{'LETSMTLOG_DIR'} . '/batch_jobs';
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

    my $status = undef;

    ## submit either to SGE ot SLURM
    if ($ENV{LETSMT_BATCHQUEUE_MANAGER} eq 'sge'){
	$status = submit_sge_job($job,$jobID,$workDir,$jobOut,$jobErr,\%args);
    }
    else{
	$status = submit_slurm_job($job,$jobID,$workDir,$jobOut,$jobErr,\%args);
    }

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

    return $jobID;
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
    if ( !$jobID && $args{path} ) {
        $jobID = get_ID_from_path( $args{path} );
    }

    #if jobID was set or could be found in mete data
    if ($jobID) {

	my $status = undef;
	if ($ENV{LETSMT_BATCHQUEUE_MANAGER} eq 'sge'){
	    $status = check_sge_job_status($jobID);
	}
	else{
	    $status = check_slurm_job_status($jobID);
	}
	if ($status){
	    $$message = $status;
	    return 1;
	}
        $$message = 'could not get status xml';
        return 0;
    }
    else {
        $$message = 'job ID not given or found in meta data';
        return 0;
    }
}


sub get_job_list {
    if ($ENV{LETSMT_BATCHQUEUE_MANAGER} eq 'sge'){
	return get_sge_job_list(@_);
    }
    else{
	return get_slurm_job_list(@_);
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
    if ( ! $jobID && $args{path} ) {
        $jobID = get_ID_from_path( $args{path} );
    }

    #if jobID was set or could be found in mete data
    if ($jobID) {
        my $status = undef;

	if ($ENV{LETSMT_BATCHQUEUE_MANAGER} eq 'sge'){
	    $status = delete_sge_job($jobID);
	}
	else{
	    $status = delete_slurm_job($jobID);
	}
	
	my $response  = LetsMT::WebService::search_meta( 'job_id' => $jobID, 
							 uid => $args{uid} );
	my $XmlParser = new XML::LibXML;
	my $dom       = $XmlParser->parse_string( $response );
	my @nodes     = $dom->findnodes('//list/entry/@path');
	$$message = "canceled job for" if (@nodes);
	foreach my $n (@nodes){
	    my $resource = LetsMT::Resource::make_from_path($n->to_literal);
	    LetsMT::WebService::post_meta(
		$resource,
		status => 'job canceled',
		uid    => $args{uid} );
	    $$message .= " ".$n->to_literal;
	}

        #TODO: delete also meta data and old log files!

        get_logger(__PACKAGE__)->debug( 'Status:' . $status );

        if ($status) {
            $$message .= $status;
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

## don't fail -- this destroys resubmit calls that try to 
## delete a job first before resubmitting ....
## TODO: find some better solution
#
#    unless ($search_result) {
#        raise( 11, 'no jobID found in meta data at this path '.$path );
#    }

    return $search_result;
}




sub _get_jobid_from_status{
    my $response = shift;
    $response     = decode( 'utf8', $response );
    my $XmlParser = new XML::LibXML;
    my $dom       = $XmlParser->parse_string( $response );
    my $jobID     = $dom->findnodes('//status')->to_literal;
    $jobID =~s/^submitted job with ID '([^']+)'.*$/$1/;
    return $jobID;
}




## SLURM-specific functions


sub submit_slurm_job {
    my ($job,$jobID,$workDir,$jobOut,$jobErr,$args) = @_;

    my ($fh, $filename) = tempfile();
    binmode( $fh, ':encoding(utf8)' );
    print $fh "#!/bin/bash\n";
    print $fh $job,"\n";
    close $fh;

    ## TODO: more options? -t for time limit? mail when finished?
    ## (check args)

    my %para = ('-n' => 1,
		'-J' => $jobID,
		'-D' => $workDir,
		'-e' => $jobErr,
		'-o' => $jobOut);
    if (ref($args) eq 'HASH'){
	$para{'-p'} = $$args{queue} if $$args{queue};
    }
    my $cmd = 'sbatch '.join(' ',%para).' '.$filename;

    get_logger(__PACKAGE__)->debug("slurm: ".$cmd);
    LetsMT::Repository::Safesys::sys($cmd);

    # get_logger(__PACKAGE__)->debug("slurm: sbatch -n 1 -J $jobID -D $workDir -e $jobErr -o $jobOut $filename");
    # LetsMT::Repository::Safesys::sys(
    #     "sbatch -n 1 -J $jobID -D $workDir -e $jobErr -o $jobOut $filename"
    # );

    # check if job was submitted
    my $status = undef;
    check_status( message => \$status, job_id => $jobID );
    # get_logger(__PACKAGE__)->debug("$jobID ... $status\n");
    return $status;
}


sub check_slurm_job_status{
    my $jobID = shift;


    #query for status of the job
    open( STATUS, "squeue -o '%j %i %T' -n $jobID |" )
	or raise( 8, "Can't run program: $!\n" );

    <STATUS>;
    my $output = <STATUS>;
    close STATUS;

    if ($output){
	my ($name,$id,$status) = split(/\s/,$output);
	return wantarray ? ($id,lc($status)) : lc($status);
    }
    return wantarray ? (undef,"no job with ID '$jobID' found") : "no job with ID '$jobID' found";
}


sub get_slurm_job_list{

    #query for status of the job
    open( STATUS, "squeue -o '%j %i %T' |" )
	or raise( 8, "Can't run program: $!\n" );

    my $entries = [];
    <STATUS>;
    while (my $output = <STATUS>){
	my ($name,$id,$status) = split(/\s/,$output);
	push( @$entries, { name => $name, id => $id, status => $status } );
    }
    close STATUS;

    my $result = {
        'path' => 'jobs',
        'entry' => $entries,
    };

    return $result;
}


sub delete_slurm_job{
    my $jobID = shift;

    my ($id,$status) = check_slurm_job_status($jobID);

    if ($id){
	$status = undef;

	#try to delete job
	open( STATUS, "scancel $id |" ) or raise( 8, "Can't run program: $!\n" );
	while (<STATUS>) {
	    $status .= $_;
	}
	close(STATUS);
	return $status;
    }

    return $status;

## don't fail -- this destroys resubmit calls that try to 
## delete a job first before resubmitting ....
## TODO: find some better solution
#
#    raise( 8, 'no job with ID '.$jobID.' found!' );
}




## SGE-specific functions

sub submit_sge_job {
    my ($job,$jobID,$workDir,$jobOut,$jobErr) = @_;

    #submit job
    LetsMT::Repository::Safesys::sys(
        "qsub -N $jobID -S /bin/bash -q letsmt -wd $workDir -e $jobErr -o $jobOut -b y \"$job\""
    );

    # check if job was submitted
    my $status = undef;
    check_status( message => \$status, job_id => $jobID );
    return $status;
}

sub get_sge_job_list{
    ## not implemented ...
}


sub check_sge_job_status{
    my $jobID = shift;

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

	return $status;
    }
    return  "no job with ID '$jobID' found";
}


sub delete_sge_job{
    my $jobID = shift;

    my $status = undef;

    #try to delete job
    open( STATUS, "qdel $jobID |" ) or raise( 8, "Can't run program: $!\n" );
    while (<STATUS>) {
	$status .= $_;
    }
    close(STATUS);
    return $status;
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
