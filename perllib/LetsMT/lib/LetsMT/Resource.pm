package LetsMT::Resource;

=head1 NAME

LetsMT::Resource - describe LetsMT resources

=head1 DESCRIPTION

The Resource class describes a resource, using four components:

=over

=item 1

    A C<slot> (a corpus name).

=item 2

    A C<user> (C<SVN>-branch).

=item 3

    A C<path> (the path of the actual file relative to the slot/user/local directory.

=item 4

    A C<local_dir> which is the place corresponding to C<slot/user> on the local storage device. This will typically be a temporary directory.

=back

=cut

use strict;
use overload '""' => \&to_string;
use File::Path;
use File::Basename;
use File::Copy;
use XML::LibXML;

use LetsMT::Lang::ISO639;
use LetsMT::Export::Reader;
use LetsMT::WebService;

use Log::Log4perl qw(get_logger :levels);


=head1 FUNCTIONS

=head2 C<is_letsmt_resource>

 &LetsMT::Resource::is_letsmt_resource ($url)

Check if C<url> is a valid LetsMT URL (and remove the heading part).

=cut

sub is_letsmt_resource {
    my ($url) = @_;

    return ( substr( $url, 0, length( $ENV{LETSMT_URL} ) + 1 )
        eq $ENV{LETSMT_URL} . '/' );
}


=head1 CONSTRUCTORS

=head2 C<new>

 $resource = new LetsMT::Resource (
     slot => '..', user => '..', path => '..', local_dir => '..'
 )

Uses a hash to construct a resource.

Any field that is not specified, or has the value C<undef>,
will be assigned the empty string (C<''>).

=cut

sub new {
    my $class = shift;
    my %self  = @_;
    $self{slot}      = '' unless ( defined $self{slot} );
    $self{user}      = '' unless ( defined $self{user} );
    $self{path}      = '' unless ( defined $self{path} );
    $self{local_dir} = '' unless ( defined $self{local_dir} );
    return bless \%self;
}


=head2 C<make> - Factory

 $resource = LetsMT::Resource::make( $slot, $user, $path, $local_dir )

Factory for making resources.

=cut

sub make {
    my ( $slot, $user, $path, $local_dir ) = @_;
    return new LetsMT::Resource (
        slot      => $slot,
        user      => $user,
        path      => $path,
        local_dir => $local_dir,
    );
}


=head2 C<make_from_path>

 $resource = LetsMT::Resource::make_from_path( $path, user, local_dir )

Make a resource object from a given path C<path>.

Tries first to use path as a complete LetsMT-URL. If this fails, tries to
use path as a path to $ENV{LETSMT_URL} and if this fails: intepret C<path> as
high-level API path.

=cut

sub make_from_path {
    return &make_from_url( @_ )
        || &make_from_relative_path( @_ )
        || &make_from_letsmt_path( @_ );
}


=head2 C<make_from_url>

 $resource = LetsMT::Resource::make_from_url( $url, user, local_dir )

Make a resource object from a given URL.

Checks if C<url> is a valid LetsMT URL
and sets C<user> if C<local_dir> points to a storage location.

=cut

sub make_from_url {
    my ( $url, $user, $local_dir ) = @_;

    # check if this is a valid LetsMT-URL
    return undef unless ( &is_letsmt_resource($url) );

    # and remove the general letsmt URL
    my $path = substr( $url, length( $ENV{LETSMT_URL} ) + 1 );
    return &make_from_path( $path, $user, $local_dir );
}


=head2 C<make_from_relative_path>

 $resource = LetsMT::Resource::make_from_relative_path(
    $path, $user, $local_dir
 )

Make a resource object from a given path.
Checks if C<path> starts with either 'storage' or 'letsmt'.
Use branch-name to set C<user> in case of storage paths.

=cut

sub make_from_relative_path {
    my ( $path, $user, $local_dir ) = @_;

    # split the path into parts
    # return undef if the URL does not point to storage or letsmt
    my @parts = split( /\//, $path );
    my $api = shift(@parts);
    return undef if ( ( $api ne 'letsmt' ) && ( $api ne 'storage' ) );

    my $slot = shift(@parts);
    $user = shift(@parts) if ( $api eq 'storage' );
    $path = join( '/', @parts );
    return &make( $slot, $user, $path, $local_dir );
}


=head2 C<make_from_storage_path>

 LetsMT::Resource::make_from_storage_path( $path, $local_dir )

Make a resource object from a given storage path.

=cut

sub make_from_storage_path {
    my ( $path, $local_dir ) = @_;

    my @parts = split( /\//, $path );
    my $slot  = shift(@parts);
    my $user  = shift(@parts);
    $path = join( '/', @parts );
    return &make( $slot, $user, $path, $local_dir );
}


=head2 C<make_from_letsmt_path>

 LetsMT::Resource::make_from_letsmt_path( $path, $user, $local_dir )

Make a resource object from a given letsmt path.

=cut

sub make_from_letsmt_path {
    my ( $path, $user, $local_dir ) = @_;

    my @parts = split( /\//, $path );
    my $slot = shift(@parts);
    $path = join( '/', @parts );
    return &make( $slot, $user, $path, $local_dir );
}


=head1 METHODS

=head2 C<basename>

Remove the initial sub-dirs of the resource path (xml/lang) and return the remaining parts.

=cut

sub basename {
    my $self = shift;
    my @path = $self->path_elements();
    shift(@path);
    shift(@path);
    return join( '/', @path );
}


=head2 C<revision>

Return the revision number of the resource, if defined.

=cut

sub revision{
    my $self = shift;

    # return revision number if it is set in the object
    return $self->{revision} if (exists $self->{revision});

    # return revision number attached to the path name
    return $1 if ( $self->{path} =~ /\@([0-9]+|HEAD)$/ );

    # OR try to get the latest revision number from the repository
    my $xml = LetsMT::WebService::get( $self );
    return undef unless (length $xml);

    my $parser = new XML::LibXML;
    my $dom;

    # make sure that the XML parser does not crash the system
    eval { $dom = $parser->parse_string( $xml ); };
    return undef if $@;

    # XML is okay --> find the commit node
    my @nodes = $dom->findnodes( '//entry/commit' );
    if (@nodes){
        $self->{revision} = $nodes[0]->getAttribute('revision');
        return $self->{revision};
    }
    return undef;
}


=head2 C<language>

When called with a parameter, set the language:

 $lang = $resource->language ($new_lang)

Otherwise, return the set language:

 $lang = $resource->language

In this case the 'lang' property is used if it exists;
if not, the resource's path is searched for valid ISO639 language names,
and the first match is returned.
If everything fails, the result is C<undef> (an empty list in list contexts).

=cut

sub language {
    my $self = shift;

    # if there is another argument: set language and change (!) the path
    return $self->set_language(@_) if ( defined $_[0] );

    # now about returning the language:
    #  - either it is already set in the resource object
    #  - or we try to find it in the path

    if ( exists $self->{lang} ) {
        return wantarray
            ? split( /\-/, $self->{lang} )
            : $self->{lang};
    }

    # get all path elements
    my @path = split( /\/+/, $self->path() );

    # check file extension for language code (for moses format)
    if ( $path[-1] =~ /\.([^\.]+)$/ ){
        my $ext = $1;
        if ( LetsMT::Lang::ISO639::iso639_exists($ext) ) {
            return $ext;
        }
    }

    ## relevant subdirs to check
    my @dir2check = ();
    push (@dir2check,$path[1]) if (@path>0);
    push (@dir2check,$path[2]) if ($path[0] eq 'uploads' && @path>1);

    ## OLD: try to find the first path element that looks like a language (pair)
    # foreach my $p (@path) {

    ## NEW: only check selected subdirs
    foreach my $p (@dir2check) {
        my @langs = split( /\-/, $p );
        my $valid = 1;
        foreach (@langs) {
            unless ( LetsMT::Lang::ISO639::iso639_exists($_) ) {
                $valid = 0;
                last;
            }
        }
        if ($valid) {
            return wantarray() ? @langs : $p;
        }
    }

    # nothing found ... return undef
    return wantarray() ? () : undef;
}



=head2 C<set_language>

 $resource->set_language ($new_lang)

Return/set resource language.

WARNING: setting the resource language changes the path!
This is only useful when creating new resources from cloned resource objects.

Either set as attribute,
or second directory in path after /xml/;
unknown otherwise.

=cut

sub set_language {
    my $self     = shift;
    my $new_lang = shift;
    my $old_lang = $self->language();

    my $oldPath = $self->local_path;
    my $oldDir  = File::Basename::dirname($oldPath);

    my @path = $self->path_elements();
    my $file = pop(@path);    # don't touch the last part!

    # replace the old language with the new one (max 2 levels deep!)
    if ($old_lang) {

    # NEW NEW:
    #  replace either first, second or third path element, if they match old_lang;
    #  otherwise: add lang as second sub-dir and delete all 'old_lang' sub-dirs

        if ( $path[0] eq $old_lang ) {
            $path[0] = $new_lang;
        }
        elsif ( ($#path > 0) && ($path[1] eq $old_lang) ) {
            $path[1] = $new_lang;
        }
        elsif ( ($#path > 1) && ($path[0] eq 'uploads') && ($path[2] eq $old_lang) ) {
            $path[2] = $new_lang;
        }
        else {
            @path = grep ($_ ne $old_lang, @path);
            my $first = shift(@path);
            unshift( @path, $new_lang );
            unshift( @path, $first ) if ($first);
        }
    }
    # ... or add the new language as the second subdir
    else {
        my $first = shift(@path);
        unshift( @path, $new_lang );
        unshift( @path, $first ) if ($first);
    }

    push( @path, $file ) if ($file);    # put the file back again!
    $self->path( join( '/', @path ) );

    ## move the old file in case it physically exists
    ## TODO: should we handle cases where the new location
    ##       is already occupied?
    if (-e $oldPath){
	my $newPath = $self->local_path;
	if ($oldPath ne $newPath){
	    my $newDir  = File::Basename::dirname($newPath);
	    File::Path::make_path( $newDir );
	    move( $oldPath,$newPath );
	}
    }
    $self->{lang} = $new_lang;

    return wantarray
        ? split( /\-/, $new_lang )
        : $new_lang;
}


=head2 C<type>

 $type = $resource->type

Return the resource type (guessing from the path if necessary).

=cut

sub type {
    my $self = shift;

    ## set type if given as argument
    ## (TODO: is that OK to make that possible?)
    if ( defined( $_[0] )){
	$self->{type} = $_[0];
	## change file extension as well if there is
	## an export reader for the given type
	## --> also move the file if it exists!
	## TODO: don't  we need to check whether there is not file 
	##       with the new name?
	if ( defined LetsMT::Export::Reader::reader($_[0]) ){
	    my $oldPath = $self->local_path;
	    $self->{path} =~ s/^(.*)\.[^\.]+$/$1.$_[0]/;
	    if (-e $oldPath){
		my $newPath = $self->local_path;
		move( $oldPath,$newPath ) unless ($oldPath eq $newPath);
	    }
	}
    }

    return $self->{type} if ( exists $self->{type} );

    # repository resources:
    #   - uploads/ includes files sorted by format
    #   - xml/     includes monolingual/parallel corpora

    my @parts = split( /\//, $self->path() );
    if ( $parts[0] eq 'uploads' ) {
        if ( my $type = $self->upload_type ) {
            return $type;
        }
    }
    elsif ( $parts[0] eq 'xml' ) {

    # check whether the path contains a language directory
    # two lang-IDs -> parallel corpus (path = '*.xml' -> only one xces file)
    # one lang-ID --> monolingual corpus (path = '*.xml' -> only one xml file)

        if ( my @lang = $self->language ) {
            if ($#lang) {
                return 'xces' if ( $self->path =~ /\.xml(\.gz)?$/ );
                return 'parallel';
            }
            else {
                return 'xml' if ( $self->path =~ /\.xml(\.gz)?$/ );
                return 'monolingual';
            }
        }
    }

    # other resource: check file extension
    # and look for a reader

    if ( $self->path =~ /\.([^.]*)$/ ) {
        my $ext = lc($1);
        return $ext if ( defined LetsMT::Export::Reader::reader($ext) );
    }

    return undef;
}


=head2 C<upload_type>

=cut

sub upload_type {
    my $self = shift;

    if ( $self->path =~ /\.([^.]*)$/ ) {
        my $ext = lc($1);
        return $ext if ( defined LetsMT::Export::Reader::reader($ext) );
    }

    my @parts = split( /\//, $self->path() );
    if ( $parts[0] eq 'uploads' ) {
        return $parts[1];
    }
    return undef;
}


=head2 C<clone>

 $resource->clone

Creates an exact copy of C<$resource>.

=cut

sub clone {
    my $self = shift;
    my %new_self;
    while ( my ( $key, $value ) = each %$self ) {
        $new_self{$key} = $value;
    }
    return bless \%new_self;
}


=head2 C<corpus>

 $resource->corpus

Create a new resource, which is identical to C<$resource>, but has no path.
This means that the created resource represents the entire corpus.

=cut

sub corpus {
    my $self = shift;
    return &make( $self->{slot}, $self->{user}, '', $self->{local_dir} );
}


=head2 $resrouce->strip_suffix

Creates a copy of C<$resource> where the first found suffix has been removed. A
suffix is identified as a dot followed by non-dots to the end of the C<path>.

=cut

sub strip_suffix {
    my $self     = shift;
    my $new_self = $self->clone;
    $new_self->{path} =~ s/^(.*)\.[^\.]*$/$1/;
    return $new_self;
}


=head2 C<graft_suffix>

 $resource->graft_suffix ($suffix)

Creates a copy of C<$resource> which has the suffix C<$suffix> added to the end
of its C<path>.

=cut

sub graft_suffix {
    my $self     = shift;
    my ($suffix) = @_;
    my $new_self = $self->clone;
    $new_self->{path} .= $suffix;
    return $new_self;
}


=head2 C<convert_type>

 $resource->convert_type ($old_type, $new_type)

B<This does not actually change the type of the resource, but only the naming of it!>

Creates a copy of C<$resource>, where instances of C<$old_type> in the beginning
and end has been replaced with C<$new_type>. The variable C<$old_type> may be a
regex.

=cut

sub convert_type {
    my $self = shift;
    my ( $old_type, $new_type ) = @_;
    my $new_self = $self->clone;

    # set the sub-directory according to the new type
    # - allow (and ignore) a leading 'uploads' dir
    # - replace the first non-'uploads' dir with new-type (if it is not the language ID)
    # - or simply add a new-type sub-dir in all other cases
    # (this looks much too complicated but seems to work fine ...)
    unless ( $new_self->{path} =~ s/^(uploads\/)?$old_type\//$1$new_type\//i ) {
        if ( $new_self->{path} =~ /^(uploads\/)?([^\/]+)\//i ) {
	    ## check whether the first non-'uploads' dir is not the language ID
	    ## if not --> replace with new type
	    if ($2 ne $self->language){
		$new_self->{path} =~ s/^(uploads\/)?[^\/]+\//$1$new_type\//i;
	    }
	}
	## if replacement didn't work --> just add the subdir of the new type
	unless ($new_self->{path} =~ /^(uploads\/)?$new_type\//i){
	    $new_self->{path} =~ s/^(uploads\/)?/$1$new_type\//i;
	}
    }

    ## NEW: delete special directories "original" and "translation"
    ##      (coming from uploads with unspecified languages)
    $new_self->{path}=~s/^(uploads\/$new_type\/)(original|translation)\//$1/;

    # set the file extension according to the new type
    # or add an extension
    unless ( $new_self->{path} =~ s/\.$old_type$/\.$new_type/i ) {

        # unless ($new_self->{path}=~s/\.[^\.]+$/\.$new_type/i){
        $new_self->{path} .= '.' . $new_type;
        # }
    }

    ## normalize path (only basic ascii characters are allowed)
    ## TODO: this is a lot of magic - does that break anything?
    # $new_self->{path}=~s/[^a-zA-Z0-9\_\-\.\/]/_/g;

    ## NEW: be a bit more permissive and allow unicode letters
    $new_self->{path}=~s/[^\p{Alnum}\_\-\.\/]/_/g;

    $new_self->type($new_type);
    return $new_self;
}



=head2 C<base_path>

 $basepath    = $resource->base_path
 $oldbasepath = $resource->base_path($new)

Return or set first element in resource path

=cut

sub base_path {
    my $self = shift;
    my $new  = shift;
    my $attr = shift || 'path';    # path attribute

    my @path_elements = $self->path_elements($attr);
    return undef unless (@path_elements);

    my $base          = $path_elements[0];
    $path_elements[0] = $new if ($new);
    $self->{$attr}    = join( '/', @path_elements );
    return $base;
}



=head2 C<path_down>

 $resource->path_down

Creates a new resource where everything from, and including, the last slash has
been removed from the C<path>.

=cut

sub path_down {
    my $self     = shift;
    my $new_self = $self->clone;
    $new_self->{path} =~ s/^(.*?)\/?[^\/]*$/$1/i;
    return $new_self;
}


=head2 C<path_to>

 $resource->path_to (@nodes)

Creates a new resource with additional nodes in the path. Accepts a list of
nodes as parameters.

=cut

sub path_to {
    my $self     = shift;
    my $new_self = $self->clone;
    $new_self->{path} = join( '/', $self->{path}, @_ );
    return $new_self;
}


=head2 C<path_elements>

 @elements = $resource->path_elements [($attribute)]

=cut

sub path_elements {
    my $self = shift;
    my $attr = shift || 'path';    # path attribute

    return split( /\/+/, $self->{$attr} );
}


=head2 C<pop_path>

 $popped = $resource->pop_path

=cut

sub pop_path {
    my $self = shift;
    my $attr = shift || 'path';    # path attribute

    my @path_elements = $self->path_elements($attr);
    my $popped        = pop(@path_elements);
    $self->{$attr}    = join( '/', @path_elements );
    return $popped;
}


=head2 C<shift_path>

 $shifted = $resource->shift_path

=cut

sub shift_path {
    my $self = shift;
    my $attr = shift || 'path';    # path attribute

    my @path_elements = $self->path_elements($attr);
    my $shifted       = shift(@path_elements);
    ## first element = empty ---> absolute path!
    ## --> take the second element and shift the empty part back
    if ($shifted eq ''){
        $shifted = shift(@path_elements);
        unshift(@path_elements,'');
    }
    $self->{$attr} = join( '/', @path_elements );
    return $shifted;
}


=head2 C<push_path>

 $new_path = $resource->push_path ($element)

=cut

sub push_path {
    my $self = shift;
    my $path = shift;
    my $attr = shift || 'path';    # path attribute

    my @path_elements = $self->path_elements($attr);
    push( @path_elements, $path );
    $self->{$attr} = join( '/', @path_elements );
    return $self->{$attr};
}


=head2 C<unshift_path>

 $new_path = $resource->unshift_path ($element)

=cut

sub unshift_path {
    my $self = shift;
    my $path = shift;
    my $attr = shift || 'path';    # path attribute

    my @path_elements = $self->path_elements($attr);
    ## first element = empty ---> absolute path!
    ## --> put the path into second place
    if (@path_elements && $path_elements[0] eq ''){
        shift(@path_elements);
        unshift( @path_elements, '', $path );
    }
    ## else: just unshift
    else{
        unshift( @path_elements, $path );
    }
    $self->{$attr} = join( '/', @path_elements );
    return $self->{$attr};
}


=head2 C<shift_path_to_local>

Shift away the first subdirectory from the path ('uploads') and move it to local_dir.

 ---> a handy function for import (when creating new resources)
 ---> make the correct path for new resources
 ---> still keep the local path accessible

This was previously done in LetsMT::Import::convert and described as:

 > Voodoo magick to harmonize paths. Makes 'uploads' a part of the
 > local path, preventing it from being a part of the paths of the
 > created resources, while still making the downloaded file available.

=cut

sub shift_path_to_local {
    my $self = shift;

    # shift aways the first path element
    # move it to local_path
    # or put it back if it is not 'uploads'

    if ( my $dir = $self->shift_path() ) {
        $dir eq 'uploads'
            ? $self->push_path( $dir, 'local_dir' )
            : $self->unshift_path( $dir, 'path' );
    }
}


=head2 C<slot> | C<user> | C<path> | C<local_dir> | C<fromDoc> | C<toDoc> | C<encoding>

 $slot = $resource->slot
 $resource->slot ($slot)
 # etc.

Getters and setters for the components.
Use C<< $slot = $resource->slot >> to get a value,
and C<< $resource->slot('testslot') >> to set a value.

When combined, a getter/setter method returns the new value.
The value C<< $user = $resource->user('me') >> thus return C<'me'>,
and not whatever the resources user field was before.

=cut

sub slot {
    return defined( $_[1] )
        ? $_[0]->{slot} = $_[1]
        : $_[0]->{slot};
}

sub user {
    return defined( $_[1] )
        ? $_[0]->{user} = $_[1]
        : $_[0]->{user};
}

sub path {
    return defined( $_[1] )
        ? $_[0]->{path} = $_[1]
        : $_[0]->{path};
}

# this is different from 'language' and 'set_language'
# because it only looks at the 'lang' attribute 
# (and does not try to match or manipulate the path of the resource)

sub lang {
    return defined( $_[1] )
        ? $_[0]->{lang} = $_[1]
        : $_[0]->{lang};
}

sub local_dir {
    return defined( $_[1] )
        ? $_[0]->{local_dir} = $_[1]
        : $_[0]->{local_dir};
}

sub fromDoc {
    return defined( $_[1] )
        ? $_[0]->{fromDoc} = $_[1]
        : $_[0]->{fromDoc};
}

sub toDoc {
    return defined( $_[1] )
        ? $_[0]->{toDoc} = $_[1]
        : $_[0]->{toDoc};
}

sub encoding {
    return defined( $_[1] )
        ? $_[0]->{encoding} = $_[1]
        : $_[0]->{encoding};
}


=head2 C<filename> | C<dirname> | C<localdirname>

Getters.

=cut

sub filename {
    return &File::Basename::basename( $_[0]->path );
}

sub dirname {
    return &File::Basename::dirname( $_[0]->path );
}

sub localdirname {
    return &File::Basename::dirname( $_[0]->local_path );
}


=head2 C<set_server>

Set server URL for the given slot.

=cut

sub set_server {
    my $self = shift;
    my $server_url = shift;
    unless ($server_url=~/^https?:\/\//){
	my $url = $ENV{LETSMT_URL};
	$url =~s/^(https?:\/\/).*?\:/$1$server_url:/;
	$server_url = $url;
    }
    $self->{server} = $server_url;
}


=head2 C<get_server>

Return server URL for the given slot.

=cut

sub get_server {
    my $self = shift;
    my $user = shift;

    return $self->{server}  if ( length $self->{server} );

    # new slot? --> return URL of this server
    my $slot = $self->slot();
    return $ENV{LETSMT_URL}  unless ( length $slot );

    # 1) try to get from metadata
    my $resource = new LetsMT::Resource( slot => $slot );
    my $response = undef;
    eval {
        $response = LetsMT::WebService::get_meta(
            $resource,
            uid => $user,
        );
    };
    return $ENV{LETSMT_URL}  if $@;

    my $parser = new XML::LibXML;
    my $dom;
    eval {
        $dom = $parser->parse_string( $response );
    };
    die( 'could not parse,' . $@ )  if $@;

    my $server_url = $dom->findnodes(
        '//list[@path=""]/entry[@path="' . $slot . '"]/server-url'
    )->to_literal;

    # 2) set to ENV{LETSMT_URL} if not found in metadata
    if ($server_url) {
        return $server_url;
    }

    # otherwise: return default URL
    return $ENV{LETSMT_URL};
}


=head2 C<to_string>

 $resource->to_string

Returns a string representation of the resource.
This method is overloaded so that a resource object can be used directly in a string.

=cut

sub to_string {
    return $_[0]->storage_path;
}


=head2 C<letsmt_path> | C<storage_path> | C<local_path>

 $path = $resource->letsmt_path
 $path = $resource->storage_path
 $path = $resource->local_path

Keeping proper track of a resource means that we always know
where to expect to find it in the repository and on the local disc.
These methods compose the various locations of the resource.

=cut

sub _path {
    my ( $self, $fields ) = @_;
    return join( '/',
        grep {$_} map { $self->{$_} } @$fields
    );
}

## TODO: should we add revision numbers to the letsmt/storage path
##       if there is a 'revision' attribute?

sub letsmt_path {
    return $_[0]->_path( [ 'slot', 'path' ] );
}

sub storage_path {
    return $_[0]->_path( [ 'slot', 'user', 'path' ] );
}

sub local_path {
    my $path = $_[0]->_path( [ 'local_dir', 'path' ] );

    # the local path should not include a revision number!
    $path =~ s/\@([0-9a-f]+|HEAD)$//;
    return $path;

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
