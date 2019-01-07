package LetsMT::Import;

=head1 NAME

LetsMT::Import - family of modules for importing data

=head1 DESCRIPTION

Import resources into the repository.

=cut

use strict;
# use utf8;

use Cwd;
use Data::Dumper;
use File::Temp 'tempdir';
use File::Basename;
use File::Copy;
use File::Path;
use Log::Log4perl qw(get_logger :levels);
use XML::Simple;
use Encode qw(decode decode_utf8 is_utf8);

use LetsMT;
use LetsMT::Import::TMX;
use LetsMT::Import::XLIFF;
use LetsMT::Import::Moses;
use LetsMT::Import::gz;
use LetsMT::Import::tar;
use LetsMT::Import::zip;
use LetsMT::Import::ApacheTika;
use LetsMT::Import::PDF;
use LetsMT::Import::Text;
# use LetsMT::Import::DOC;
use LetsMT::Import::SRT;
use LetsMT::Import::SRTsimple;
use LetsMT::Import::XML;


use LetsMT::Resource;
use LetsMT::WebService;
use LetsMT::Tools;
use LetsMT::Lang::Detect;

use LetsMT::DataProcessing::Tokenizer;
use LetsMT::DataProcessing::Tokenizer::No;
use LetsMT::DataProcessing::Normalizer;
use LetsMT::DataProcessing::Normalizer::No;
use LetsMT::DataProcessing::Splitter;
use LetsMT::DataProcessing::Splitter::No;
use LetsMT::DataProcessing::UDPipe;

use LetsMT::Corpus;
use LetsMT::Align;
use LetsMT::Align::Words;

use LetsMT::Repository::GroupManager;
use LetsMT::Repository::JobManager;


=head1 VARIABLES

=head2 C<$TYPES>

A hash reference to a catalogue of document types mapped to import handlers. To
activate a new import handler it needs to be registered in this struct.

An import handler is any class that supplies the two methods
C<validate(LetsMT::Resource)> and C<convert(LetsMT::Resource, LetsMT::Import>.
The target format for the C<convert> method should always be the internal LetsMT
flavor of xces.

Each resource being imported should result in a list of new resources, each
described by a hash. The returned structure should have this format:
 [
     {
         resource => LetsMT::Resource,
         meta => {
             key1 => value1,
             key2 => value2,
             ...
         }
     },
     ...
 ]

=cut

# type patterns for recognizing MS Word documents
# (used by validation with Apache Tika)

my @doc_content_types = (
    'Content-Type: application\/msword',
    'Application-Name: Microsoft Office Word',
    'Content-Type: application\/vnd.openxmlformats-officedocument.wordprocessingml.document'
    );
my $doc_type_pattern = join( '|', @doc_content_types );


my $TYPES = {
    tmx   => new LetsMT::Import::TMX,
    xlf   => new LetsMT::Import::XLIFF,
    moses => new LetsMT::Import::Moses,
    gz    => new LetsMT::Import::gz,
    tar   => new LetsMT::Import::tar,
    zip   => new LetsMT::Import::zip,
    pdf   => new LetsMT::Import::PDF,
    txt   => new LetsMT::Import::Text,
#    doc   => new LetsMT::Import::DOC,
#    doc   => new LetsMT::Import::Tika(
    doc   => new LetsMT::Import::ApacheTika(
        type => 'doc',
        type_pattern => '(?:doc|docx)',
        content_type_pattern => $doc_type_pattern ),
    srt   => new LetsMT::Import::SRT,
    # srt => new LetsMT::Import::SRTsimple
    xml   => new LetsMT::Import::XML,
#    unknown   => new LetsMT::Import::Tika
    unknown   => new LetsMT::Import::ApacheTika
};

$TYPES->{text}     = $TYPES->{txt};
$TYPES->{xliff}    = $TYPES->{xlf};
$TYPES->{tgz}      = $TYPES->{tar};
$TYPES->{'tar.gz'} = $TYPES->{tar};
$TYPES->{'docx'}   = $TYPES->{doc};
$TYPES->{rawxml}   = $TYPES->{xml};


# IMPORTANT:
# list all pre-aligned formats for which no auto-sentence-alignment
# should be performed!

my @SKIP_AUTO_ALIGN = qw( tmx xliff moses );


=head2 Defaults

All defaults are declared as C<our>, which makes them visible to anyone using
the module.

C<$DEFAULT_TOKENIZER>

C<$DEFAULT_NORMALIZER>

C<$DEFAULT_SPLITTER>

C<$DEFAULT_LANG = 'xx'>

C<%DEFAULT_LANG_SPLITTER>

=cut

our $DEFAULT_TOKENIZER  = new LetsMT::DataProcessing::Tokenizer::No;
our $DEFAULT_NORMALIZER = new LetsMT::DataProcessing::Normalizer::No;
our $DEFAULT_SPLITTER   = new LetsMT::DataProcessing::Splitter::No;
our $DEFAULT_LANG       = 'xx'; # was 'en' before but this only hides not properly imported files, hence 'xx'

# default sentence splitters for specific languages
# (will be used if the 'lang' argument is set and no other splitter is given)

our %DEFAULT_LANG_SPLITTER = (
    ##
    ## add language-specific splitters here if you like!
    ## splitters need to be defined in LetsMT::DataProcessing::Splitter
    ##
    #  en => new LetsMT::DataProcessing::Splitter(method => 'my_english_splitter'),
    #  de => new LetsMT::DataProcessing::Splitter(method => 'my_german_splitter'),
    #               ....
);


=head1 METHODS

=head2 Constructor

 $importer = new LetsMT::Import (%OPTIONS)

OPTIONS:

 local_root ... (default: a new temporary directory)
 splitter ..... (default: one given in %DEFAULT_LANG_SPLITTER)
 lang ......... (language key for the choice of the default splitter)

If no C<local_root> key is given to the constructor, a new temporary directory will be created and used.

=cut

sub new {
    my $class = shift;
    my %self  = @_;

    #
    # Build look-up functions
    #  - they will be used to find appropriate import handlers
    #    according to the resource type specified in path and suffix
    #
    $self{suffix_lookup}
        = &LetsMT::Tools::build_lookup_func( $TYPES, '\.', '$' );
    $self{path_lookup}
        = &LetsMT::Tools::build_lookup_func( $TYPES, '^uploads\/', '\/' );

    #
    # Ensure local root (temp dir)
    #
    my $tmpdir = $ENV{LETSMT_TMP} || '/tmp';
    unless ( defined $self{local_root} ){
        $self{local_root} = tempdir(
            'import_XXXXXXXX',
            DIR     => $tmpdir,
            CLEANUP => 1
        );
    }

    #
    # set language-specific sentence splitters if they are defined
    # in %DEFAULT_LANG_SPLITTER (and no other splitter is given)
    #

    if ( exists $self{lang} ) {
        unless ( exists $self{splitter} ) {
            if ( exists $DEFAULT_LANG_SPLITTER{ $self{lang} } ) {
                $self{splitter} = $DEFAULT_LANG_SPLITTER{ $self{lang} };
            }
        }
    }

    #
    # Return blessed reference
    #
    bless \%self, $class;
    return \%self;
}


=head2 C<supported>

 $importer->supported ($type)

=cut

sub supported {
    my $type = shift;
    return 1 if ( exists $TYPES->{$type} );
    return 0;
}


=head2 C<import_file>

 $importer->import_file ($user, $slot, $path)

Creates a new resource with C<$slot>, C<$user>, C<$path> and the C<local_root>
of the importer, and imports that resource with C<import_resource>.

=cut

sub import_file {
    my $self = shift;
    my ( $user, $slot, $path ) = @_;

    return $self->import_resource(
        &LetsMT::Resource::make( $slot, $user, $path, $self->{local_root} ) );
}


=head2 C<import_resource>

 $importer->import_resource ($resource, %args)

Fetches a resource from the repository (should be from the C<uploads> directory)
and attempts to run all possible import handlers to get a new set of resources
which are uploaded back to the repository. Returns true if conversion was
successful and false otherwise.

=cut

sub import_resource {
    my $self            = shift;
    my $resource        = shift;
    my %args            = @_;

    my $skip_align      = $args{skip_align} ? $args{skip_align} : undef;
    my $skip_find_align = $args{skip_find_align} ? $args{skip_find_align} : undef;
    my $skip_parsing    = $args{skip_parsing} ? $args{skip_parsing} : undef;
    my $skip_wordalign  = $args{skip_wordalign} ? $args{skip_wordalign} : undef;

    $self->{new_resources} = [];
    $resource->local_dir( $self->{local_root} )
        unless ( $resource->local_dir );

    ## NEW: only import if status != imported and no failed imports
    my $response = LetsMT::WebService::get_meta( $resource );
    # eval{ $response = decode( 'utf8', $response ) };
    $response = decode( 'utf8', $response );
    # $response = decode( 'utf8', $response, sub{ return ' ' } );
    # $response = decode( 'utf8', $response, Encode::FB_PERLQQ );
    # utf8::decode($response);
    my $XmlParser = new XML::LibXML;
    my $dom       = $XmlParser->parse_string($response);
    my @nodes     = $dom->findnodes('//list/entry');
    if (@nodes){
	$self->{status} = $nodes[0]->findvalue('status');
	## for archives: check the count for failed imports
	if ( $nodes[0]->findvalue('import_failed_count') > 0 ){
	    $self->{status} = 'partially imported';
	}
	if ($self->{status} eq 'imported'){
	    print "resource ".$resource->path." is already imported\n";
	    return wantarray ? () : 1;
	}
    }

    # TODO: shouldn't we check if the resource exists before
    #       we write meta data for it?
    # Make sure there is a meta entry for the resource.

    &LetsMT::WebService::post_meta( $resource,
        status => 'importing');

    # reset some metainformation related to data imports
    &LetsMT::WebService::del_meta(
        $resource,
        import_log      => '',
        import_logfiles => '',
        import_runtime  => '',
        imported_to     => ''
    );

    my $slot   = $resource->slot();
    my $branch = $resource->user();
    my $corpus = &LetsMT::Resource::make( $slot, $branch );

    # Get requested resource
    unless ( &LetsMT::WebService::get_resource($resource) ) {
        get_logger(__PACKAGE__)->error("Unable to fetch resource: $resource");
        &LetsMT::WebService::post_meta( $resource,
            status => 'failed to fetch' );
        &LetsMT::WebService::del_meta( $corpus,
            'import_queue' => $resource->path );
        &LetsMT::WebService::put_meta( $corpus,
            'import_failed' => $resource->path );
	return wantarray ? () : 0;
    }

    #-------------------------------------------------------------------
    # Convert resource
    #
    ## NEW: all new resources are already uploaded in convert_resource!
    ##      --> partial imports will create resources even if the
    ##          import process crashes!

    my $start = time();
    my $new_resources = $self->convert_resource( $resource, $resource );
    #-------------------------------------------------------------------

    # Remove resource from import queue (meta-data for corpus)
    &LetsMT::WebService::del_meta(
        $corpus,
        'import_queue' => $resource->path
    );

    # import success if new_resources is a reference to an array!
    if ( ref($new_resources) eq 'ARRAY' ) {

	## check import parameters (unless they are given already)
	unless (defined $skip_align && defined $skip_parsing && defined $skip_wordalign){
	    my %para = &get_import_parameter($corpus);
	    $skip_align     = $para{autoalign}     eq 'off' ? 1 : 0; # default = on
	    $skip_parsing   = $para{autoparse}     eq 'on'  ? 0 : 1; # default = off
	    $skip_wordalign = $para{autowordalign} eq 'on'  ? 0 : 1; # default = off
	}

        #-------------------------------------------------------------------
        ## check if we should align some documents
        ## (monolingual documents with the same name but different language)
        ##
        ## this is only done for non-pre-aligned data
        ## (need to skip pre-aligned data by adding them 
        ##  to the SKIP_AUTO_ALIGN list)

	my @aligned_resources = ();
	unless ($skip_find_align){
	    my $upload_type = $resource->upload_type;
	    unless (grep ($_ eq $upload_type, @SKIP_AUTO_ALIGN ) ){
		## if skip_align: do not align but still look for translated documents
		## and save alignment candidates in metadata
		if ( $skip_align ){
		    &save_align_candidates( $corpus, @$new_resources );
		}
		else {
		    @aligned_resources = &align_documents( $corpus, @$new_resources );
		    # push ( @$new_resources, @aligned_resources);
		    if ($args{email}=~/\S+\@\S+/){
			&send_bitexts_as_tmx( $args{email}, \@aligned_resources );
		    }
		}
	    }
	}

	## this should be done by align_resources now .....
        # #-------------------------------------------------------------------
	# ## convert to TMX
	# foreach my $r (@aligned_resources){
	#     my @path_elements = split(/\/+/,$r->storage_path);
	#     LetsMT::Repository::JobManager::run_make_tmx(\@path_elements);
	# }

        #-------------------------------------------------------------------
	## parse all monolingual resources using UDPipe
	unless ($skip_parsing){
	    my @resources = &get_monolingual_resources(@$new_resources);
	    my $udpipe = new LetsMT::DataProcessing::UDPipe;
	    foreach my $r (@resources) {
		my @path_elements = split(/\/+/,$r->storage_path);
		if (my $newres = LetsMT::Repository::JobManager::run_parse(\@path_elements)){
		    push (@$new_resources,$newres);
		}
	    }
	}

        #-------------------------------------------------------------------
	## now even run word alignment for sentence aligned documents!
	unless ($skip_wordalign){
	    foreach my $res (@aligned_resources){
		my @path_elements = split(/\/+/,$res->storage_path);
		my @newres = 
		    LetsMT::Repository::JobManager::run_wordalign(\@path_elements);
		foreach my $n (@newres){
		    push (@$new_resources,$n);
		}
	    }
	}

        ## update resource status!
	my $status = 'imported';
        &LetsMT::WebService::del_meta(
            $corpus,
            'import_queue' => $resource->path,
            'import_failed' => $resource->path );
        &LetsMT::WebService::post_meta(
            $resource,
            'status'         => $status,
            'import_runtime' => time() - $start);

	return wantarray ? @$new_resources : 1;
    }

    # import failed!
    else {
        &LetsMT::WebService::post_meta(
            $resource,
            'status'          => 'import failed',
            'import_runtime'  => time() - $start);
        &LetsMT::WebService::put_meta(
            $corpus,
            'import_failed'   => $resource->path );
    }
    return wantarray ? () : 0;
}


## send a bitext as TMX via email
## TODO: should we create one global TMX for multiple aligned documents?

sub send_bitexts_as_tmx{
    my $email  = shift;
    my $algres = shift;

    return unless (ref($algres) eq 'ARRAY');
    foreach my $tmxres (@$algres){
	$tmxres->base_path('tmx');
	if (resource_exists($tmxres)){
	    LetsMT::WebService::get( $tmxres, 
				     email => $email,
				     action => 'download',
				     archive => 'no' );
	}
	else{
	    my @path_elements = split(/\/+/,$tmxres->storage_path);
	    LetsMT::Repository::JobManager::run_make_tmx( \@path_elements,
							  email => $email );
	}
    }
}



=head2 C<align_documents>

=cut

sub align_documents {
    my $corpus    = shift;

    my $AlignResources = &find_translations( $corpus, @_ );

    return 0 unless ( ref($AlignResources) eq 'ARRAY' );

    my $LastFrom = undef;
    my %AlignPara = ();
    my %Langs     = ();
    my %LangPairs = ();

    my $count = 0;
    my @AlignedResources = ();
    foreach my $a ( @{$AlignResources} ){
	my $FromRes = $a->{from};
	my $ToRes   = $a->{to};
	my $AlgRes  = $a->{align};

	my $logger = get_logger(__PACKAGE__);
	$logger->info("align $FromRes with $ToRes ... ");

	## reload align-paras only if we move to a new FromRes
	%AlignPara = &get_align_parameter( $FromRes ) 
	    unless ( $LastFrom && ($LastFrom eq $FromRes) );

	my $aligner = new LetsMT::Align( %AlignPara );
	print "aligning: ".$FromRes->path." and ".$ToRes->path."\n";
	if ( $aligner->align_resources( $FromRes, $ToRes, $AlgRes ) ) {
	    $logger->info("done!");
	    ## save language info for meta data (see below)
	    my @lang = $AlgRes->language();
	    my $pair = join( '-', @lang );
	    $LangPairs{$pair}++;
	    foreach ( @lang ){ $Langs{$_}++; }
	    push( @AlignedResources, $AlgRes );
	    $count++;
	}
	else { $logger->error("align $FromRes with $ToRes failed!"); }
    }

    ## update corpus metadata about languages and language pairs
    if ($count){
        &LetsMT::WebService::put_meta(
	     $corpus,
	     'parallel-langs' => join( ',', sort keys %LangPairs ),
	     'langs'          => join( ',', sort keys %Langs )
	    );
    }

    return wantarray ? @AlignedResources : $count;
    # return $count;
}


=head2 C<save_align_candidates>

Find translated documents and store information for each source resource.
Do not align any document pair!

=cut

sub save_align_candidates {
    my $corpus    = shift;

    my $AlignResources = &find_translations( $corpus, @_ );
    return 0 unless ( ref($AlignResources) eq 'ARRAY' );

    # hash of candidates for each resource
    my %candidates = ();
    my %resources  = ();

    my $count = 0;
    foreach my $a ( @{$AlignResources} ){
	my $from = $a->{from}->path;
	my $to   = $a->{to}->path;
	$candidates{$from}{$to}++;
	$resources{$from} = $a->{from};
	$count++;
    }

    foreach my $src ( keys %candidates ){
	my $trg = join( ',', sort keys %{$candidates{$src}} );
        &LetsMT::WebService::put_meta(
	    $resources{$src},
	    'align-candidates' => $trg );
    }
    return $count;


}



=head2 C<find_translations>

=cut

sub find_translations {
    my $corpus          = shift;
    my @resources       = @_;

    ## sort the resources
    my @MonoResources  = get_monolingual_resources( @resources );
    my @ParallelPath   = get_sentalign_files( @resources );
    return [] unless (@MonoResources);

    # save aligned resources in this hash
    my %AlignedRes = ();

    # TODO: it's a bit arbitrary to use the first monolingual resource only
    #       to fetch parameters for searching parallel documents
    my %AlignPara = &get_align_parameter( $MonoResources[0] );

    ## find all parallel resources
    # my %MatchingResources = 
    #     &LetsMT::Corpus::find_parallel_resources(
    #        $corpus,
    #        \@MonoResources,
    #        %AlignPara
    #    );

    ## TODO: no align parameters used below anymore!
    ## --> is this still compatible?
    my %MatchingResources = 
        &LetsMT::Corpus::find_translations(
            $corpus,
            \@MonoResources,
        );



    ## initialize return structure
    my $AlignResources = [];

    # find parallel documents for each monolingual resource
    foreach my $SrcRes (@MonoResources) {
        my $SrcFile = $SrcRes->storage_path;
        next unless (ref($MatchingResources{$SrcFile}) eq 'HASH');
        my @matching = values %{$MatchingResources{$SrcFile}};

        foreach my $TrgRes (@matching) {

            # swap if needed (language IDs need to be sorted)
            my ( $FromRes, $ToRes )
                = $SrcRes->language() gt $TrgRes->language()
                ? ( $TrgRes, $SrcRes )
                : ( $SrcRes, $TrgRes );

            # create the alignment resource
            my $AlgRes
                = &LetsMT::Align::make_align_resource( $FromRes, $ToRes );
            my $AlgPath = $AlgRes->path();

            # check if we have done this pair already ....
            next if ( defined $AlignedRes{$AlgPath} );

            # check if the alignment file is not part of this resource
            next if ( grep ( $AlgPath eq $_, @ParallelPath ) );

	    push( @{$AlignResources}, { from => $FromRes, 
					to => $ToRes,
					align => $AlgRes } );

	    $AlignedRes{$AlgPath} = $AlgRes;
        }
    }
    return $AlignResources;
}



=head2 C<get_monolingual_resources>

Return all monolingual resources from a list
of resources created by import_resources

=cut

sub get_monolingual_resources {
    my @resources     = @_;
    my @MonoResources = ();
    foreach my $nr (@resources) {
        if ( $nr->{resource}->type() ne 'xces' ) {
	    if ( $nr->{resource}->base_path() eq 'xml' ) {
		push( @MonoResources, $nr->{resource} );
	    }
        }
    }
    return @MonoResources;
}

sub get_sentalign_files {
    my @resources     = @_;
    my @ParallelPath  = ();
    foreach my $nr (@resources) {
        if ( $nr->{resource}->type() eq 'xces' ) {
            push( @ParallelPath,  $nr->{resource}->path() );
        }
    }
    return @ParallelPath;
}



=head2 C<convert_resource>

 $importer->convert_resource ($resource[, $meta_resource[, $print_progress]])

Finds a handler for one resource and applies it to that resource.
Useful when converting archives, as it can be used to convert a resource
without involving the repository.
The optional C<$meta_resource> is the resource that collects meta information from the import process.
No progress information is written by default.

=cut

sub convert_resource {
    my $self            = shift;
    my $resource        = shift;                 # resource to be imported
    my $meta_resource   = shift || $resource;    # place where to put metainfo
    my $report_progress = shift;                 # report progress in metadata
    my $out_resource    = shift;                 # optional output resource

    #----------------------------------------------------------
    # get possible resource handlers and try them
    #----------------------------------------------------------

    # get possible resource handlers
    my @handlers = $self->get_resource_handlers($resource);

    # cumulative list of errors (logfiles and metainfo)
    my @errors;

    foreach my $handler (@handlers) {
        my ($validation_errors,      # error resources and metainfo
            $validation_warnings,    # warning resources and metainfo
            $log_message             # import-log
        ) = $handler->validate($resource);

        # upload possible warnings (logfiles, messages etc)
        &_upload_errors( $validation_warnings, $resource, $meta_resource, $log_message );

        # add validation errors to global list of errors
        push( @errors, @$validation_errors );

        #--------------------------------------------
        # No errors? --> Validation is OK! Try to convert ...
        #--------------------------------------------

        unless ( scalar @$validation_errors ) {
	    print "converting: ".$resource->path." ... ";
            my ($new_resources,       $conversion_errors,
                $conversion_warnings, $log_message
                ) = $handler->convert( $resource, $self, $meta_resource, $report_progress, $out_resource );

            # upload possible warnings (logfiles, messages etc)
            &_upload_errors(
                $conversion_warnings, $resource,
                $meta_resource,       $log_message
            );

            # make sure that conversion errors points to an array!
            $conversion_errors = []
                unless ( ref($conversion_errors) eq 'ARRAY' );

            # add validation errors to global list of errors
            push( @errors, @$conversion_errors );

            # no errors? --> conversion is succesful!
            #            --> return newly created resources
            # TODO: an empty list of new_resources is interpreted as a failure!
            #       Questions: is that OK?

            unless ( scalar @$conversion_errors ) {

                ## NEW: upload all converted resources
                ## ---> don't have to wait until all files in large archives
                ##      are processed!
                if ( ref( $new_resources ) eq 'ARRAY' ) {
                    foreach my $nr (@$new_resources) {
                        $self->upload_new_resource( $nr, $meta_resource );
                    }
                }
		print "ok\n";
                return $new_resources;
            }
	    print "failed\n";
        }
    }

    #--------------------------------------------
    # If import failed, commit all accumulated errors
    #--------------------------------------------

    &_upload_errors( \@errors, $resource, $meta_resource );

    # return an undefined reference
    # (which will be interpreted as a failure)
    return undef;
}



=head2 C<upload_new_resource>

 $importer->upload_new_resource ( $new_resource, $original_resource )

Upload a new resource coming from a conversion process.
C<$new_resource> is a pointer to a hash
C<{ resource => resource_object, meta => \%meta_data }>.
C<$original_resource> is the resource object that has been converted.

Note: Resource-types 'xml' will be run through language detection before uploading them to the repository!

=cut


sub upload_new_resource{
    my $self = shift;
    my ($new_res, $from_res ) = @_;

    # don't import again if already imported before
    return 1 if ($new_res->{status} eq 'imported');

    ## NEW: don't upload before language check!
    # get_logger(__PACKAGE__)->info( 'New resource: ', $new_res->{resource} );
    # push @{ $self->{new_resources} }, $new_res->{resource};
    # &LetsMT::WebService::put_resource( $new_res->{resource} );

    ## old call to post_meta with empty metadata hash ... why?
    # &LetsMT::WebService::post_meta( $new_res->{resource} );

    ########################################
    ## NEW: skip language checks here
    ## ---> this should be done earlier
    ##      when converting files
    ## ---> TODO: we don't get meta data for mismatches!
    ########################################

    # # for all monolingual corpus files: do language detection!!!
    # # TODO: should this be done earlier?
    # if ($new_res->{resource}->type eq 'xml'){
    #     my @lang = $new_res->{resource}->language();
    #     if ($#lang == 0){
    #         my @detected = &detect_language($new_res->{resource});
    #         if ( $detected[0] ne 'unknown' ){
    #             # unless ( grep( $_ eq $lang[0], @detected ) ){
    #             unless ( $#detected == 0 && $detected[0] eq $lang[0] ){
    #                 if ($detected[0] eq $lang[0]){
    #                     $new_res->{meta}->{warning} = 
    #                         'possible language mismatch';
    #                 }
    #                 elsif (grep($_ eq $lang[0],@detected)){
    #                     $new_res->{meta}->{warning} = 
    #                         'likely language mismatch';
    #                 }
    #                 else{
    # 			## NEW: overwrite old language!
    # 			##      (this is especially necessary for user-contributed
    # 			##       data and webcrawled data!)
    # 			$new_res->{resource}->set_language($detected[0]);
    #                     $new_res->{meta}->{warning} = 'language mismatch! old language = ';
    # 			$new_res->{meta}->{warning}.= $lang[0];
    #                 }
    #                 $new_res->{meta}->{detected_languages} = 
    #                     join( ',', @detected );
    #             }
    #         }
    #     }
    # }

    ## NEW: upload resource AFTER language check
    get_logger(__PACKAGE__)->info( 'New resource: ', $new_res->{resource} );
    push @{ $self->{new_resources} }, $new_res->{resource};
    &LetsMT::WebService::put_resource( $new_res->{resource} );

    ## update meta data
    $new_res->{meta}->{'imported_from'} => &utf8_to_perl( $from_res->path );
    &LetsMT::WebService::post_meta( $new_res->{resource},
                                    %{ $new_res->{meta} } );

    # update metadata on corpus level
    my $slot   = $from_res->slot();
    my $branch = $from_res->user();
    my $corpus = &LetsMT::Resource::make( $slot, $branch );
    &update_corpus_meta( $corpus, $new_res->{resource} );

    # add information about the newly created resource on corpus level
    &LetsMT::WebService::put_meta( $from_res,
           'imported_to' => $new_res->{resource}->path );

    # mark this resource as being imported already
    $new_res->{status} ='imported';

}




=head2 C<update_corpus_meta>

Set some global information to the slot/branch = corpus:
Update the available languages (langs) and language pairs (parallel-langs).

=cut

sub update_corpus_meta {
    my ( $corpus, $resource ) = @_;

    if ( $resource->type() eq 'xces' ) {
        my @lang = $resource->language();
        &LetsMT::WebService::put_meta(
            $corpus,
            'parallel-langs' => join( '-', @lang ),
            'langs'          => join( ',', @lang )
        );
    }
    else {
        my $lang = $resource->language();
        &LetsMT::WebService::put_meta( $corpus, 'langs' => $lang );
    }
}





# C<_upload_errors>
# For internal use only.

sub _upload_errors {
    my ( $error_resources, $current_resource, $original_resource, $log ) = @_;

    # array of error resource names (will be added to the
    # metadata of the original_resource as 'import_logfiles')
    my @resource_names = ();

    # loop through error resource array
    # should be a reference to ($resource,%metainfo)

    foreach my $r (@$error_resources) {
        if ( ref($r) eq 'ARRAY' ) {
            my $res = shift( @{$r} );

            # this looks weird but this is necessary because of the
            # recursive call to import_resource:
            #   current_resource may be a new resource created by
            #   a conversion in the previous step (e.g. PDF->Text)
            # we do not want to upload these intermediate files as new
            # error resource but only store their metadata with the
            # original resource (--> set $res to $original_resource)
            if ( $res->path eq $current_resource->path ) {
                $res = $original_resource;
            }

            # upload a resource if they are not the same
            # as the original resource that we try to import
            # + save the name in @logfiles
            if ( $res->path ne $original_resource->path ) {
                &LetsMT::WebService::put_resource($res);
                push( @resource_names, $res->path );
            }

            # add meta data
            &LetsMT::WebService::put_meta( $res, @$r ) if (@$r);
        }
    }

    my %meta;
    if ($log) {
        $meta{import_log} = $log;
    }

    # if there were error resource: add resource list to metadata!
    if (@resource_names) {
        $meta{import_logfiles} = join( ',', @resource_names );
    }

    # add metadata to the original resource if necessary
    if ( keys %meta ) {
        &LetsMT::WebService::put_meta( $original_resource, %meta );
    }
}


=head2 C<get_resource_handlers>

 $importer->get_resource_handlers ($resource)

Returns a list of handlers to try on C<$resource> based on path and suffix.

=cut

#
# TODO: this way of looking up handlers feels extra-ordinary complicated
#       why do we need this complicated way of calling lookup functions
#       instead of getting the first path element and the file suffix
#       to take appropriate handlers from the TYPES hash ....?
#
## changed now ... this is still a bit ad-hoc but is a bit cleaner

sub get_resource_handlers {
    my $self = shift;
    my ($resource) = @_;

    my @handlers;

    my $suffix_type = suffix_type( $resource->path );
    my $path_type   = path_type( $resource->path );

    ## moses over-rules suffix-types
    if ($path_type eq 'moses'){
	push( @handlers, $$TYPES{$path_type} );
    }

    ## otherwise: suffix-patterns are first
    push( @handlers, $$TYPES{$suffix_type} ) 
	if (defined $suffix_type && exists $$TYPES{$suffix_type});

    ## path-types are second
    if ($path_type && $path_type ne 'moses'){
	if ($path_type ne $suffix_type){
	    push( @handlers, $$TYPES{$path_type} ) if (exists $$TYPES{$path_type});
	}
    }

    ## check resource type and try to detect with Apache Tika if necessary
    if (my $type = $resource->type()){
	push( @handlers, $$TYPES{$type} ) if (exists $$TYPES{$type});
    }
    elsif (! @handlers){
	$TYPES->{unknown}->validate($resource);
	if (my $type = $resource->type()){
	    push( @handlers, $$TYPES{$type} ) if (exists $$TYPES{$type});
	}
    }

    ## add default handler if no other found
    push(@handlers,$TYPES->{unknown}) unless @handlers;


## OLD style for lookup functions
## 
#     # #
#     # # Add directory typing
#     # #
#     # my $path_handler = $self->{path_lookup}->( $resource->path );
#     # push @handlers, $path_handler if ( defined $path_handler );

#     # #
#     # # Add suffix typing
#     # #
#     # my $suffix_handler = $self->{suffix_lookup}->( $resource->path );
#     # if ( defined $suffix_handler ) {
#     #     unless ( grep( $_ eq $suffix_handler, @handlers ) ) { # avoid existing
#     #         push @handlers, $suffix_handler;
#     #     }
#     # }
#
#     ## take the generic handler for unknown formats
#     ## if no other handler is found (Apache Tika)
#     push(@handlers,$TYPES->{unknown}) unless @handlers;

    ## set additional parameters for each import handler
    foreach my $h (@handlers){
        $h->set_parameter( &get_import_parameter($resource) );
    }

    return @handlers;
}


## NEW 2018-08-20: simplify type lookup

sub suffix_lookup{
    my $self = shift;
    my $path = shift;

    if ($path=~/\.([^.]+)(\.gz)?$/i){
	return $TYPES->{$1} if (exists $TYPES->{$1});
    }
    return undef;
    # return $self->{suffix_lookup}->( $path );
}

sub path_lookup{
    my $self = shift;
    my $path = shift;

    my @parts = split(/\/+/,$path);
    return $$TYPES{$parts[1]} if ($parts[0] eq 'uploads' && exists $$TYPES{$parts[1]});
    return $$TYPES{$parts[0]} if (exists $$TYPES{$parts[0]});
    return undef;
#     return $self->{path_lookup}->( $path );
}



## return suffix type

sub suffix_type{
    my $path = shift;

    if ($path=~/\.([^.]+)(\.gz)?$/i){
	return $1 if (supported($1));
    }
    return 'gz' if ($path=~/\.(gz)$/i);
    return undef;
}

sub path_type{
    my $path = shift;

    my @parts = split(/\/+/,$path);
    return $parts[1] if ($parts[0] eq 'uploads' && supported($parts[1]));
    return $parts[0] if (supported($parts[0]));
    return undef;
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
