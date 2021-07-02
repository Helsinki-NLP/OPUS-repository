package LetsMT::Repository::Resource;

use parent 'LetsMT::Resource';

use LetsMT::Repository::StorageManager;
use LetsMT::Repository::MetaManager;

use Log::Log4perl qw(get_logger :levels);



=head2 C<revision>

Return the revision number of the resource, if defined.

=cut


## overwrite existing function to make it independent of WebService calls

sub revision{
    my $self = shift;

    # return revision number if it is set in the object
    return $self->{revision} if (exists $self->{revision});

    # return revision number attached to the path name
    return $1 if ( $self->{path} =~ /\@([0-9]+|HEAD)$/ );

    get_logger(__PACKAGE__)->debug("get revision for ".$self->storage_path." from storage manager ...");
    my $xml = undef;
    my @path = split(/\/+/,$self->storage_path);
    return undef unless (&LetsMT::Repository::StorageManager::existent(
			      path => \@path,
			      rev  => undef,
			      uid  => $self->{user} ));
    &LetsMT::Repository::StorageManager::list_storage( \$xml, \@path, $self->{user}, 'show' );
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





=head2 C<get_server>

Return server URL for the given slot.

=cut


## always assume that the internal slots are on the current server
sub get_server {
    return $ENV{LETSMT_URL};
}


    
1;
