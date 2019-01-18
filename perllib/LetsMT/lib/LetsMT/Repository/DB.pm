package LetsMT::Repository::DB;

=head1 NAME

LetsMT::Repository::DB - a module for storing and manipulating metadata

=head1 SYNOPSIS

 use LetsMT::Repository::DB::TokyoCabinet;
 
 # open the default database (LETSMTDISKROOT/metadata.tct)
 my $metaDB = new LetsMT::Repository::DB::TokyoCabinet();
 
 $metaDB->open();
 ## alternative: specify database file:
 # $metaDB->open('/path/to/database.tct');
 
 #------
 ## via the network:
 # use LetsMT::Repository::DB::TokyoTyrant;
 # my $metaDB = new LetsMT::Repository::DB::TokyoTyrant(
 #      -host => 'localhost', -port => 1234);
 #------
 
 # insert some data records:
 $metaDB->post( "id1", {size => int(rand(100000)),
                        tags => 'big,nice,free',
                        owner => 'me',
                        lang => 'en',
                        type => 'monolingual'} );
 $metaDB->post( "id2", {size => int(rand(100000)),
                        tags => 'small,ugly,free',
                        owner => 'me',
                        srclang => 'en',
                        trglang => 'sv',
                        type => 'parallel'} );
 $metaDB->post( "id3", {size => int(rand(100000)),
                        tags => 'big,ugly,free',
                        owner => 'someone else',
                        srclang => 'en',
                        trglang => 'fr',
                        type => 'parallel'} );
 
 # find all records with one of the following tags: nice OR big
 my $results = $metaDB->search({ONE_OF_tags => 'nice,big'});
 foreach (@{$results}){
    print "match: $_\n";
 }
 
 # find all records with all of the following tags: nice AND free
 # return matches wrapped in XML
 my $xml = $metaDB->search_xml({ALL_OF_tags => 'nice,free'});
 print $xml;
 
 # two conditions
 my $results = $metaDB->search({owner => 'me' , type => 'parallel'});
 foreach (@{$results}) {
    print "match: $_\n";
 }
 
 # numeric comparison (MIN = '>=' and MAX = '<=')
 my $results = $metaDB->search({MIN_size => 10000 , MAX_size => 80000});
 foreach (@{$results}) {
     print $metaDB->get_xml($_);
 }
 
 # update a record and add another key-value pair
 $metaDB->put("id3", { time => time(), owner => 'me' });
 print $metaDB->get_xml('id3');
 
 # delete a specific key
 $metaDB->delete("id3", 'time');
 print $metaDB->get_xml('id3');
 
 # delete the whole record
 $metaDB->delete("id3");
 print $metaDB->get_xml('id3');
 
 # iterate over all data records
 $metaDB->iter_start();
 while (my $data = $metaDB->get_next) {  # we could also call get_next_xml()
   print "owner: ",$data->{owner},"\n";
 }
 
 $metaDB->close();

=head1 DESCRIPTION

MetaData.pm uses Tokyo Cabinet, a flexible inplementation of DBM with support for tables including arbitrary fields.
More information about the software can be found here: L<http://fallabs.com/tokyocabinet/>.

=cut

use strict;

use open qw(:std :utf8);

# possible MetaData interfaces:
use LetsMT::Repository::DB::TokyoCabinet;
use LetsMT::Repository::DB::TokyoTyrant;

use LetsMT::Repository::Err;
use Log::Log4perl qw(get_logger :levels);

#-----------------------------------------------------------------------------
# CONSTRUCTOR
#-----------------------------------------------------------------------------

=head1 CONSTRUCTOR

=cut

sub new {
    my $class = shift;
    my %attr  = @_;

    if ( $attr{-type} eq 'tc' ) {

        # get_logger(__PACKAGE__)->debug( 'using TokyoCabinet' );
        return new LetsMT::Repository::DB::TokyoCabinet(%attr);
    }
    else {

        # get_logger(__PACKAGE__)->debug( 'using TokyoTyrant' );
        $attr{'-host'} = $attr{'-host'} || $LetsMT::TT_META_HOST;
        $attr{'-port'} = $attr{'-port'} || $LetsMT::TT_META_PORT;
        return new LetsMT::Repository::DB::TokyoTyrant(%attr);
    }
}


#-----------------------------------------------------------------------------
# define some general methods that can be inherited by DB sub-classes
#-----------------------------------------------------------------------------

=head1 METHODS

=head2 C<open>

 $metaDB->open
 $metaDB->open ($path)

Open the database (default: open for read/write access).

=cut

sub open {
    my $self = shift;

    return $self->open_write(@_);
}


=head2 C<get_xml>

 $xml = $metaDB->get_xml( \$msg, $id, $key )

Execute C<get> and wrap the results in XML.

=cut

sub get_xml {
    my ( $self, $message, $id, $key ) = @_;

    my %entry = ( path => $id );

    my $data = $self->get( $id );
    raise( 7, 'ID not found', 'info' )  unless ( defined $data && keys %$data );

    $$message = 'Found matching path ID. Listing all of its properties';
    foreach my $data_key ( keys %$data ) {
        $entry{$data_key} = [ $data->{$data_key} ];
    }

    # Build hash ref for result
    my $result = {
        'path'  => '',
        'entry' => [ \%entry ],
    };

    return $result;
}


# wrap search results in XML
# deprecated
sub search_xml_old {
    my $self   = shift;
    my $result = $self->search(@_);

    my $string = "<lists>\n";

    foreach my $id ( @{$result} ) {
        my $data = $self->get($id);
        if ( ref($data) eq 'HASH' ) {
            $string .= _format_entry( $id, $data );
        }
    }

    $string .= "</lists>\n";

    return $string;
}


=head2 C<search_xml>

 $xml = $metaDB->search_xml( $result_type, \$msg, $search )

Wrap search results in XML.

=cut

# TODO: check search
sub search_xml {
    my $self        = shift;
    my $result_type = shift;
    my $message     = shift;
    my $search      = shift || {};

    # check if the action key contains post-processing operations
    # like summing over values (SUM) or getting max/min values (MAX/MIN)
    # ---> create new result_type 4!!!!!!!
    my %operation = ();
    if ( defined $search->{action} ) {
        if ( $search->{action} =~ /(SUM|MAX|MIN)/ ) {
            $result_type = 4;
            my @op = split( /\,/, $search->{action} );
            foreach (@op) {
                if (/(SUM|MAX|MIN)\_(.*)/) {
                    $operation{$2} = $1;
                }
            }
            delete $search->{action};
        }
    }

    my $result = $self->search($search);

    $$message = 'Found ' . scalar @$result . ' matching entries';

    my $entries = [];

    if ( $result_type == 1 ) {    # action=list_all
        $self->list_all_entries( $result, $entries );
    }
    elsif ( $result_type == 3 ) {    # action=count
        $$entries[0] = { type => 'search result', count => [ $#{$result} + 1 ] };
    }

    # apply other operations over result lists
    elsif ( $result_type == 4 ) {
        $self->apply_query_operation( $result, \%operation, $entries );
    }
    else {    #default: list only IDs of matching entries
        foreach my $id ( @{$result} ) {
            push( @$entries, { path => $id } );
        }
    }

    # Build hash ref for result
    my $result = {
        'path' => $$search{STARTS_WITH__ID_} || '',
        'entry' => $entries,
    };

    return $result;
}


=head2 C<list_all_entries>

=cut

sub list_all_entries {
    my ( $self, $ids, $entries ) = @_;
    foreach my $id ( @{$ids} ) {
        my $data  = $self->get($id);
        my %entry = ();

        foreach my $key ( keys %$data ) {
            $entry{$key} = [ $data->{$key} ];
        }
        if ( ref($data) eq 'HASH' ) {
            push( @$entries, { path => $id, %entry, } );
        }
    }
}


=head2 C<apply_query_operation>

=cut

sub apply_query_operation {
    my ( $self, $ids, $operation, $entries ) = @_;
    my %entry = ();
    foreach my $id ( @{$ids} ) {
        my $data = $self->get($id);
        foreach my $k ( keys %{$operation} ) {
            if ( defined $$data{$k} ) {
                my $key = $$operation{$k} . '_' . $k;

                # make sure the key exists and points to a hash
                # (this is needed for formatting with XML::Simple)
                $entry{$key} = {} if ( !defined $entry{$key} );

                # summing values
                if ( $$operation{$k} eq 'SUM' ) {
                    $entry{$key}{content} += $$data{$k};
                }

                # minimum value
                elsif (
                    $$operation{$k} eq 'MIN'
                    && ( ( !defined $entry{$key}{content} )
                        || $$data{$k} < $entry{$key}{content} )
                    )
                {
                    $entry{$key}{content} = $$data{$k};
                    $entry{$key}{path}    = $id;
                }

                # maximum value
                elsif (
                    $$operation{$k} eq 'MAX'
                    && ( ( !defined $entry{$key}{content} )
                        || $$data{$k} > $entry{$key}{content} )
                    )
                {
                    $entry{$key}{content} = $$data{$k};
                    $entry{$key}{path}    = $id;
                }
            }
        }
    }
    $$entries[0] = {
        type  => 'search result',
        count => [ $#{$ids} + 1 ],
        %entry
    };
}


=head2 C<get_gid>

Get gid for given resources ABOVE slot level.

=cut

# return gid for given resources ABOVE slot level!
# (always take this from the branch metadata!)

sub get_gid {
    my ( $self, $id ) = @_;

    # otherwise: get gid from branch-level
    my @path = split( '/', $id );
    
    if ( scalar @path > 1 ) {
        my $data = $self->get( $path[0] . '/' . $path[1] );        
        return $$data{gid} if ( exists $$data{gid} );
    }

    # this should only happen on slot & branch-level
    return undef;
}


=head2 C<get_owner>

=cut

# return owner of a resource
# (usually the one that owns the entire branch)

sub get_owner {
    my ( $self, $id ) = @_;

    # return owner or creator if it is set
    my $data = $self->get($id);
    return $$data{owner}   if ( exists $$data{owner} );
    return $$data{creator} if ( exists $$data{creator} );

    # otherwise: get owner from branch-level
    my @path = split( '/', $id );
    if ($#path) {
        my $data = $self->get( $path[0] . '/' . $path[1] );
        return $$data{owner} if ( exists $$data{owner} );
        return $path[1];    # default = branch name
    }

    # this should only happen on slot & branch-level
    return undef;
}


#-----------------------------------------------------------------------------
# empty stubs for methods that have to be implemented by classes
# derived from the DB
#-----------------------------------------------------------------------------

=head1 ABSTRACT METHODS

Must be implemented in child classes.

=head2 C<open_read> | C<open_write> | C<close> | C<hotocopy> | C<db_handle> | C<delete>

=cut

# open for reading

sub open_read {
    get_logger(__PACKAGE__)->fatal('open_read is not implemented in base class!');
    return 0;
}

# open for read & write

sub open_write {
    get_logger(__PACKAGE__)->fatal('open_write is not implemented in base class!');
    return 0;
}

# close DB

sub close {
    get_logger(__PACKAGE__)->fatal('close is not implemented in base class!');
    return 0;
}

# make a hotcopy of the DB

sub hotcopy {
    get_logger(__PACKAGE__)->error('hotcopy is not implemented in base class!');
    return 0;
}

# return DB handle

sub db_handle {
    get_logger(__PACKAGE__)->error('db_handle is not implemented in base class!');
    return undef;
}

# delete data record

sub delete {
    get_logger(__PACKAGE__)->fatal('delete is not implemented in base class!');
    return 0;
}

=head2 C<delete_recursive> | C<put_recursive> | C<post_recursive> | C<delete_all>

=cut

# delete_recursive($prefix)
#--------------------------
# delete all data records with IDs that start with $prefix

sub delete_recursive {
    get_logger(__PACKAGE__)->fatal('delete recursive is not implemented in base class!');
    return 0;
}

# put_recursive($prefix)
#--------------------------
# update all data records recursively

sub put_recursive {
    get_logger(__PACKAGE__)->fatal('put_recursive not implemented in base class!');
    return 0;
}

# put_recursive($prefix)
#--------------------------
# update all data records recursively

sub post_recursive {
    get_logger(__PACKAGE__)
        ->fatal('post_recursive is not implemented in base class!');
    return 0;
}

# delete all records in the database

sub delete_all {
    get_logger(__PACKAGE__)
        ->fatal('delete_all is not implemented in base class!');
    return 0;
}

=head2 C<post> | C<put> | C<get> | C<key_exists> | C<search> | C<copy>

=cut

# $success = post($id,\%datahash)
#--------------------------------
# post a new data record to the database
# (overwrite existing keys)

sub post {
    get_logger(__PACKAGE__)->fatal('post is not implemented in base class!');
    return 0;
}

# $success = put($id,\%datahash)
#-------------------------------
# put a data record to the database
# (add values to existing keys)

sub put {
    get_logger(__PACKAGE__)->fatal('put is not implemented in base class!');
    return 0;
}

# $datahash = get($id,$key)
#-------------------------------
# return data record for the given ID
# $key = optional

sub get {
    get_logger(__PACKAGE__)->fatal('get is not implemented in base class!');
    return 0;
}

sub key_exists {
    get_logger(__PACKAGE__)->fatal('key_exists is not implemented in base class!');
    return 0;
}

# $list = search($id,%conditions)
#----------------------------------
# return a list (reference to array of IDs) of matching data records
# conditions = { key => pattern, ... }
#    key may include special query operators
#    (see LetsMT::Repository::DB::TokyoCabinet::search)

sub search {
    get_logger(__PACKAGE__)->fatal('search is not implemented in base class!');
    return 0;
}

# copy($oldpref, $newpref, $uid)
#--------------------------------
# copy all data records with IDs that start with $oldpref
# to data records with ID's that start with $newpref
# (replace $oldpref with $newpref)
# ---> this is for copying metadata when creating new branches)
# uid = optional (set uid attribute for all copied data records)

sub copy {
    get_logger(__PACKAGE__)->fatal('copy is not implemented in base class!');
    return 0;
}

# index is an alias for add_index

sub index {
    my $self=shift;
    return $self->add_index(@_);
}

sub add_index {
    get_logger(__PACKAGE__)->fatal('add_index is not implemented in base class!');
    return 0;
}

sub delete_index {
    get_logger(__PACKAGE__)->fatal('delete_index is not implemented in base class!');
    return 0;
}

sub optimize_index {
    get_logger(__PACKAGE__)->fatal('optimize_index is not implemented in base class!');
    return 0;
}




#-----------------------------------------------------------------------------
# class internal methods
#-----------------------------------------------------------------------------

=head1 INTERNAL UTILITY METHODS

=head2 C<_format_key>

=cut

# format keys in XML
# deprecated
sub _format_key {
    my ( $data, $key ) = @_;
    my $string = '';

    if ( defined $key && exists $data->{$key} ) {
        $string = '      <' . $key . '>' . $data->{$key} . '</' . $key . ">\n";
    }
    else {
        foreach my $data_key ( sort keys %{$data} ) {
            $string .= '      <' . $data_key . '>'
                . $data->{$data_key} . '</'
                . $data_key . ">\n";
        }
    }

    return $string;
}


=head2 C<_format_entry>

=cut

# wrap data entries in XML
# deprecated
sub _format_entry {
    my ( $id, $data, $key ) = @_;

    my $kind = $data->{'resource-type'} || 'unknown';

    my $string = "  <list path=\"$id\">\n";
    $string .= "    <entry kind=\"$kind\">\n";
    $string .= _format_key( $data, $key );
    $string .= "    </entry>\n";
    $string .= "  </list>\n";

    return $string;
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
