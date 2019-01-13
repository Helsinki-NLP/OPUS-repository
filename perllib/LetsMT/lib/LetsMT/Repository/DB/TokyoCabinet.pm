package LetsMT::Repository::DB::TokyoCabinet;

=head1 NAME

LetsMT::Repository::DB::TokyoCabinet - a module for storing and manipulating metadata

=cut

use strict;
use parent 'LetsMT::Repository::DB';

use open qw(:std :utf8);
use Encode qw(decode encode);
use utf8;

use LetsMT::Tools;
use TokyoCabinet;
use Time::HiRes qw(time);

use Data::Dumper;
use LetsMT::Repository::Err;
use Log::Log4perl qw(get_logger :levels);

# derive methods from DB
# IMPORTANT: overwrite constructor!

$Data::Dumper::Terse  = 1;    # don't output names where feasible
$Data::Dumper::Indent = 0;    # save space (no pretty printing)

# $Data::Dumper::Indent = 1;     # readable output (but not too fancy)
# $Data::Dumper::Indent = 2;     # full indentation (default in Data::Dumper)

## set the following flag to use DEBUG mode for TokyoCabinet!

# $TokyoCabinet::DEBUG = 1;

our $STARTOPTIMIZE_SIZE = 500000000;    # try to optimize if filesize > 500MB


=head1 CONSTRUCTOR

 $db = new LetsMT::Repository::DB::TokyoCabinet( %opts )

 -no_logging ......... don't log transactions!
 -no_transactions .... don't use transactions!

=cut

sub new {
    my $class = shift;
    my %self  = @_;

    bless \%self, $class;

    # create the TDB object
    $self{TDB} = TokyoCabinet::TDB->new();

    # define the standard database
    if ( not defined $self{-database} ) {
        if ( not defined $ENV{LETSMTDISKROOT} ) {
            get_logger(__PACKAGE__)->fatal('LETSMTDISROOT not defined');
            raise( 8, 'LETSMTDISROOT not defined' );
        }
        else {
            my $dir = $ENV{LETSMTDISKROOT};
            $self{-database} = $dir . '/metadata.tct';
        }
    }

    return \%self;
}


=head1 DESTRUCTOR

Make sure that the DB gets closed again.

=cut

DESTROY {
    my $self = shift;
    $self->close();
}


=head1 METHODS

=head2 C<open_read>

=cut

sub open_read {
    my $self     = shift;
    my $database = shift || $self->{-database};
    my $tdb      = $self->{TDB};

    # make sure the DB is closed
    $self->close();

    # open in write mode if it not exists (create DB file!)
    # if (! -e $database){ return $self->open_write($database); }
    return 0 unless ( -e $database );

    if ( !$tdb->open($database) ) {
        my $ecode = $tdb->ecode();    # error code
        get_logger(__PACKAGE__)
            ->fatal( 'DB open error' . $tdb->errmsg($ecode) );
        raise( 7, 'could not open database for read access', 'fatal' );
        return 0;
    }

    # check if we need to optimize the database file ....
    #$self->auto_optimize(); #TODO: Instead of calling this for every open, it should be scheduled via cron

    $self->{-database} = $database;
    $self->{OPEN} = 1;
    return 1;
}


=head2 C<open_write>

=cut

sub open_write {
    my $self     = shift;
    my $database = shift || $self->{-database};
    my $tdb      = $self->{TDB};

    # make sure the DB is closed
    $self->close();

    if ( !$tdb->open( $database, $tdb->OWRITER | $tdb->OCREAT ) ) {
        my $ecode = $tdb->ecode();    # error code
        get_logger(__PACKAGE__)
            ->fatal( 'DB open error: ' . $tdb->errmsg($ecode) );
        raise( 7, 'could not open database for write access', 'fatal' );
        return 0;
    }

    # TODO: should we try to repair if open fails?
    # (try at least to run $tdb->optimize() ?)
    #
    # this would call optimize when the database exceeds a certain size:
    # $self->auto_optimize();

    $self->{-database} = $database;
    $self->{OPEN} = 1;
    return 1;
}


=head2 C<hotcopy>

=cut

sub hotcopy {
    return $_[0]->{TDB}->copy( $_[1] );
}


=head2 C<db_handle>

=cut

sub db_handle {
    return $_[0]->{TDB};
}


=head2 C<close>

=cut

sub close {
    my $self = shift;
    if ( $self->{OPEN} ) {
        if ( $self->{TDB}->close() ) {
            delete $self->{OPEN};
            return 1;
        }
        else {
            raise( 7, 'could not close database', 'fatal' );
        }
    }
    return 0;
}


=head2 C<delete_all>

Full reset --> delete all records!!

=cut

sub delete_all {
    my $self = shift;
    if ( ref( $self->{TDB} ) ) {
        return $self->{TDB}->vanish();
    }
    return 0;
}


=head2 C<auto_optimize>

=cut

sub auto_optimize {
    my $self = shift;
    if ( ref( $self->{TDB} ) ) {
        my $tdb  = $self->{TDB};
        my $fsiz = $tdb->fsiz;
        if ( $fsiz > $STARTOPTIMIZE_SIZE ) {
            my $rnum = $tdb->rnum;
            get_logger(__PACKAGE__)
                ->info( 'MetaData: current file size: ' . $fsiz );
            get_logger(__PACKAGE__)
                ->info( 'MetaData: current number of records: ' . $rnum );
            get_logger(__PACKAGE__)
                ->info('MetaData: try to optimize the database!');
            $tdb->optimize();
            my $fsiz = $tdb->fsiz;
            get_logger(__PACKAGE__)
                ->info( 'MetaData: new file size: ' . $fsiz );
        }
    }
}


=head2 C<optimize>

=cut

sub optimize {
    my $self = shift;
    if ( ref( $self->{TDB} ) ) {
        return $self->{TDB}->optimize();
    }
    return 0;
}


=head2 C<add_index>

=cut

sub add_index {
    my $self = shift;

    my %args = @_;
    my $name = $args{name};
    my $type = $args{type} || 'lexical';

    if ( ref( $self->{TDB} ) ) {
	my %INDEX_TYPES = ( lexical => $self->{TDB}->ITLEXICAL,
			    decimal => $self->{TDB}->ITDECIMAL,
			    token => $self->{TDB}->ITTOKEN,
			    qgram => $self->{TDB}->ITQGRAM );

	my $logger = get_logger(__PACKAGE__);

	return 'no name' && $logger->warn("no name for DB index") unless $name;
	return 'unknown type' && $logger->warn("unknown DB index type '$type'") 
	    unless (exists $INDEX_TYPES{$type} );
	if ($self->open()){
	    if ($self->{TDB}->setindex( $name, $INDEX_TYPES{$type} )){
		$self->close();
		return "successfully created $type index for field '$name'";
	    }
	    $self->close();
	}
    }
    return "failed to created $type index for field '$name'";
}

=head2 C<delete_index>

=cut

sub delete_index {
    my $self = shift;

    my %args = @_;
    my $name = $args{name};

    if ( ref( $self->{TDB} ) ) {
	return 'no name' && get_logger(__PACKAGE__)->warn("no name for DB index") 
	    unless $name;
	if ($self->open()){
	    if ( $self->{TDB}->setindex( $name, $self->{TDB}->ITVOID ) ){
		$self->close();
		return "successfully removed index for field '$name'";
	    }
	    $self->close();
	}
    }
    return "failed to remove index for field '$name'";
}

=head2 C<optimize_index>

=cut

sub optimize_index {
    my $self = shift;

    my %args = @_;
    my $name = $args{name};

    if ( ref( $self->{TDB} ) ) {
	return 'no name' && get_logger(__PACKAGE__)->warn("no name for DB index") 
	    unless $name;
        if ( $self->open ){
	    if ( $self->{TDB}->setindex( $name, $self->{TDB}->ITOPT ) ){
		$self->close();
		return "successfully optimized index for field '$name'";
	    }
	    $self->close();
	}
    }
    return "failed to optimize index for field '$name'";
}




=head2 C<post>

Update a data record (create if it doesn't exist).
# (reserved key _ID_ with id --> needed for recursive delete etc)

=cut

sub post {
    my ( $self, $id, $newData ) = @_;
    my $tdb = $self->{TDB};

    my $data = $tdb->get($id) || {};    # get old metadata record

    foreach ( keys %{$newData} ) {
	# avoid rubbish keys
	if (/^HASH\([0-9defx]+\)$/i){
            get_logger(__PACKAGE__)->error("post meta: got corrupt data!\n");
	    next;
	}

	## crazy decoding / encoding to make sure that
	## we get the string in correct internal format
	utf8::decode($newData->{$_});
	utf8::encode($newData->{$_});

        $data->{$_} = $newData->{$_};
    }

    # set gid (should always be the same as branch-level gid!)
    # should only return undef for slot-level IDs

    my @path_parts = split('/',$id);

    #overwrite/set gid only for path levels above branch
    if ( (scalar @path_parts > 2) && (my $gid = $self->get_gid($id)) ) {
        $data->{gid} = $gid;
    }

    # finally: insert the data
    my $success = $self->_tdb_put( $tdb, $id, $data );

    ## TODO: is it OK to fail here or can this lead to locked DBs
    ## (should be OK as the DESTROY operation takes care of closing ...)
    $success or raise( 11, 'Could not write to meta DB', 'error' );

    return $success;
}


=head2 C<put>

Add a new key--value pairs to the data
(add new string elements in fields that already exist).

=cut

sub put {
    my ( $self, $id, $newData ) = @_;
    my $tdb = $self->{TDB};

    my $data = $tdb->get($id) || {};

    foreach ( keys %{$newData} ) {

	## crazy decoding / encoding to make sure that
	## we get the string in correct internal format
	utf8::decode($newData->{$_});
	utf8::encode($newData->{$_});

	# avoid rubbish keys
	if (/^HASH\([0-9defx]+\)$/i){
            get_logger(__PACKAGE__)->error("put meta: got corrupt data!\n");
	    next;
	}
        $data->{$_} = _merge_values( $data->{$_}, $newData->{$_} );
    }
    return $self->post( $id, $data );
}


=head2 C<get_strict>

Get a data record.
# TODO: should we make it possible to return only values for an optional key?

=cut

sub get_strict {
    my ( $self, $id, $key ) = @_;

    my $data = $self->{TDB}->get($id);

    # TODO: this decoding business is quite annoying
    # is this really necessary?!?
    map( $$data{$_} = decode( 'UTF-8', $$data{$_} ), keys %{$data} );
    # map( utf8::decode( $$data{$_} ), keys %{$data} );

    if ( ref($data) eq 'HASH' ) {    # delete special key _ID_
        delete $data->{_ID_};        # (only for internal use!)
    }
    else {
        raise( 7, "ID '$id' not found", 'info' );
    }

    return $data;
}


=head2 C<get>

A bit more tolerant than the above:

Returns string,
empty hash if the ID is not found.

=cut

# try to split the string on commas if an array is required as return value

sub get {
    my ( $self, $id, $key ) = @_;
    my $data = $self->{TDB}->get($id);

    if ( ref($data) eq 'HASH' ) {    # delete special key _ID_
        # TODO: this decoding business is quite annoying
        # is this really necessary?!?
	map( $$data{$_} = decode( 'UTF-8', $$data{$_} ), keys %{$data} );
	# map( utf8::decode( $$data{$_} ), keys %{$data} );

        # a key is given: return only that value!
        # (as an array if necessary)
        if ( defined $key ) {
            return wantarray ? split( /,/, $$data{$key} ) : $$data{$key};
        }
        delete $data->{_ID_};        # (only for internal use!)
        return $data;
    }

    return undef if ( defined $key );    # no empty hash if a key is given!
    return {};
}


=head2 C<key_exists>

=cut

sub key_exists {
    my ( $self, $id ) = @_;
    my $data = $self->{TDB}->get($id);
    return 1 if ( ref($data) eq 'HASH' );
    return 0;
}


=head2 C<search>

Query the database with simple conditions (conjunction only!)

Special treatment for fields that start with:

  ONE_OF_ ....... use keyword search in a string (OR)
  ALL_OF_ ....... use keyword search in a string (AND)
  STARTS_WITH_ .. search prefix
  ENDS_WITH_ .... search suffix
  MIN_ .......... numeric comparison (>=)
  MAX_ .......... numeric comparison (<=)

=cut

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# WARNING: no type check here!!!!
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

sub search {
    my $self = shift;
    my $cond = shift || {};

    # optional arguments
    # OrderField: sort by that field
    # OrderType: ascending/descending (default: ascending)
    # MaxReturn: max number of records to return
    # SkipRecords: skip this number of records

    my ( $OrderField, $OrderType, $MaxReturn, $SkipRecords ) = @_;

    my $tdb = $self->{TDB};
    my $qry = TokyoCabinet::TDBQRY->new($tdb);

    foreach my $key ( keys %{$cond} ) {
        if ( $key =~ s/^ONE_OF_// ) {
            $qry->addcond( $key, $qry->QCSTROR, $cond->{ 'ONE_OF_' . $key } );
        }
        elsif ( $key =~ s/^ALL_OF_// ) {
            $qry->addcond( $key, $qry->QCSTRAND,
                $cond->{ 'ALL_OF_' . $key } );
        }
        elsif ( $key =~ s/^STARTS_WITH_// ) {
            $qry->addcond( $key, $qry->QCSTRBW,
                $cond->{ 'STARTS_WITH_' . $key } );
        }
        elsif ( $key =~ s/^ENDS_WITH_// ) {
            $qry->addcond( $key, $qry->QCSTREW,
                $cond->{ 'ENDS_WITH_' . $key } );
        }
        elsif ( $key =~ s/^INCLUDES_// ) {
            $qry->addcond( $key, $qry->QCSTRINC,
                $cond->{ 'INCLUDES_' . $key } );
        }
        elsif ( $key =~ s/^REGEX_// ) {
            $qry->addcond( $key, $qry->QCSTRRX,
                $cond->{ 'REGEX_' . $key } );
        }
        elsif ( $key =~ s/^MIN_// ) {
            $qry->addcond( $key, $qry->QCNUMGE, $cond->{ 'MIN_' . $key } );
        }
        elsif ( $key =~ s/^MAX_// ) {
            $qry->addcond( $key, $qry->QCNUMLE, $cond->{ 'MAX_' . $key } );
        }
        elsif ( $key =~ s/^NOT_// ) {
            $qry->addcond(
                $key,
                $qry->QCNEGATE | $qry->QCSTREQ,
                $cond->{ 'NOT_' . $key }
            );
        }
        else {
            $qry->addcond( $key, $qry->QCSTREQ, $cond->{$key} );
        }
    }

    my $qcorder
        = $qry->QOSTRDESC ? $OrderType eq 'descending' : $qry->QOSTRASC;
    $qry->setorder( $OrderField, $qcorder );
    $qry->setlimit( $MaxReturn, $SkipRecords );

    # finally: run the query!
    # TODO: why do we need to decode everything?
    my $result = $qry->search();
    @{$result} = map( decode( 'UTF-8', $_ ), @{$result} );
    return $result;
    # return $qry->search();
}


=head2 C<delete>

Delete a specific key-value pair in a data record.

- if no value is given or '*' --> delete whatever value is stored in key

- if no key is given: delete entire entry!

=cut

sub delete {
    my ( $self, $id, %keys ) = @_;
    my $tdb = $self->{TDB};

    # return value
    my $success = 0;

    # delete the data record
    if ( !keys %keys ) {
        # delete the data record
        $success = $self->_tdb_delete( $tdb, $id );
        $success or raise( 7, 'Could not delete meta data record', 'error' );
    }

    # delete key in record (get, update, post)
    elsif ( my $data = $tdb->get($id) ) {
        my $changes = 0;
        foreach my $k ( keys %keys ) {
            if ( exists $data->{$k} ) {
                if ( ( not defined $keys{$k} ) || ( $keys{$k} eq '*' ) ) {
                    delete $data->{$k};
                }
                else {    # No check here if value to be deleted exists at all
                    $data->{$k} = _remove_value( $data->{$k}, $keys{$k} );
                }
                $changes++;
            }
        }
        if ($changes){
            $success = $self->_tdb_put( $tdb, $id, $data );
            $success
                or raise( 7, 'Could not delete value(s) from meta data record', 'error' );
        }
    }
    return $success;
}


=head2 C<copy>

Copy all metadata records for IDs with a specific prefix
to new records with the old prefix replaced by a new one
(this is useful when copying branches!)

optional $uid: set new uid for all copied elements

=cut

sub copy {
    my ( $self, $oldpref, $newpref, $uid ) = @_;
    my $tdb = $self->{TDB};

    return 0 if ( not defined $oldpref );
    return 0 if ( not defined $newpref );

    my $qry = TokyoCabinet::TDBQRY->new($tdb);
    $qry->addcond( '_ID_', $qry->QCSTRBW, $oldpref );

    my $count  = 0;
    my $result = $qry->search();    # search for all entries
    foreach my $id ( @{$result} ) { # where _ID_ starts with prefix
        my $data = $tdb->get($id);
        if ($data) {
            $count++;

            # replace old prefix with new prefix
            # and change status to 'copied' (to mark copied files!)
            substr( $data->{_ID_}, 0, length($oldpref), $newpref );
            $data->{status} = 'copied';
            $data->{owner} = $uid if ( defined $uid );
            $self->_tdb_put( $tdb, $data->{_ID_}, $data );
        }
    }
    return $count;
}


=head2 C<delete_recursive>

Delete recursive for all resource items below path (dangerous!).
if $prefix ends with '/' --> delete only sub-resources
otherwise: also delete resource $prefix (together with all sub-resources)

=cut

sub delete_recursive {
    my ( $self, $path ) = @_;
    my $tdb = $self->{TDB};

    return 0 if ( not defined $path );    # we need to have a prefix!

    # add '/' at the end to avoid substring matches
    # (for example prefix='/my/path' would also match '/my/pathos/...')
    my $prefix = $path;
    $prefix .= '/' if ( $path !~ /\/$/ );

    my $count = 0;
    my $qry   = TokyoCabinet::TDBQRY->new($tdb);
    $qry->addcond( '_ID_', $qry->QCSTRBW, $prefix );

    # search for all entries where _ID_ starts with prefix and delete them!
    my $result = $qry->search();

    # delete all matching entries
    foreach my $id ( @{$result} ) {
        $count++ if ( $self->delete($id) );
    }

    # if we added a trailing / --> delete even the path record (if it exists)!
    if ( $path ne $prefix ) {
        if ( $tdb->get($path) ) {
            $count++ if ( $self->delete($path) );
        }
    }
    return $count;
}

sub put_recursive {
    my $self = shift;
    return $self->do_recursive( 'put', @_ );
}

sub post_recursive {
    my $self = shift;
    return $self->do_recursive( 'post', @_ );
}


# add metadata recursively to all records below the given path

sub do_recursive {
    my ( $self, $method, $path, $data ) = @_;
    my $tdb = $self->{TDB};

    return 0 if ( not defined $path );    # we need to have a prefix!

    # add '/' at the end to avoid substring matches
    # (for example prefix='/my/path' would also match '/my/pathos/...')
    my $prefix = $path;
    $prefix .= '/' if ( $path !~ /\/$/ );

    my $count = 0;
    my $qry   = TokyoCabinet::TDBQRY->new($tdb);
    $qry->addcond( '_ID_', $qry->QCSTRBW, $prefix );

    # search for all entries where _ID_ starts with prefix and delete them!
    my $result = $qry->search();

    # delete all matching entries
    foreach my $id ( @{$result} ) {
        $count++ if ( $self->$method( $id, $data ) );
    }

    # if we added a trailing / --> delete even the path record (if it exists)!
    if ( $path ne $prefix ) {
        if ( $tdb->get($path) ) {
            $count++ if ( $self->$method( $path, $data ) );
        }
    }

    return $count;
}


# iterate through the database ....

sub iter_start {
    my $self = shift;
    my $tdb  = $self->{TDB};
    return $tdb->iterinit();
}

sub get_next {
    my $self = shift;
    my $data = shift;
    if ( my $id = $self->get_next_key() ) {
        return $self->get($id);
    }
    return undef;
}

sub get_next_xml {
    my $self = shift;
    my $data = shift;
    if ( my $id = $self->get_next_key() ) {
        return $self->get_xml($id);
    }
    return undef;
}

sub get_next_key {
    my $self = shift;
    my $data = shift;
    my $tdb  = $self->{TDB};
    return $tdb->iternext();
}


#-----------------------------------------------------------------------------
# class internal methods
#-----------------------------------------------------------------------------

# merge values from newData and oldData
# - allow only unique values

sub _merge_values {
    my ( $oldData, $newData ) = @_;
    my @oldValues = split( /\,/, &utf8_to_perl( $oldData ) );
    my @newValues = split( /\,/, &utf8_to_perl( $newData ) );
    my %values    = ();
    foreach (@oldValues) { $values{$_} = 1; }
    foreach (@newValues) { $values{$_} = 1; }
    return join( ',', keys %values );
}


# remove a specific value from a data entry

sub _remove_value {
    my ( $data, $value ) = @_;
    my @values = split( /\,/, $data );
    my @new = ();
    foreach my $v (@values) {
        if ( $v ne $value ) {
            push( @new, $v );
        }
    }
    return join( ',', @new );
}


#----------------------------------------------------------------------------
# interaction with TDB: write and delete transactions
#----------------------------------------------------------------------------

sub _tdb_put {
    my ( $self, $tdb, $id, $data ) = @_;

    unless ( $self->{-no_transactions} ) {

        # start a transaction
        if ( !$tdb->tranbegin() ) {
            my $ecode = $tdb->ecode();
            my $err   = $tdb->errmsg($ecode);
            get_logger(__PACKAGE__)->error("put error: $err\n");
            return 0;
        }
    }

    # get logfile for transaction
    my $logfile = $self->_get_logfile($tdb);

    # try to put the data record into the database
    # always add key '_ID_' as one of the fields!

    $data->{_ID_} = $id;
    if ( !$tdb->put( $id, $data ) ) {
        my $ecode = $tdb->ecode();
        my $err   = $tdb->errmsg($ecode);
        get_logger(__PACKAGE__)->error("put error: $err\n");
        unless ( $self->{-no_transactions} ) {
            if ( !$tdb->tranabort() ) {
                my $ecode = $tdb->ecode();
                my $err   = $tdb->errmsg($ecode);
                get_logger(__PACKAGE__)->error("put error: $err\n");
            }
        }
        delete $data->{_ID_};
        return 0;
    }
    delete $data->{_ID_};

    unless ( $self->{-no_transactions} ) {

        # commit transaction
        if ( !$tdb->trancommit() ) {
            my $ecode = $tdb->ecode();
            my $err   = $tdb->errmsg($ecode);
            get_logger(__PACKAGE__)->error("put error: $err\n");
            return 0;
        }
    }

    # log transaction
    $self->_log_transaction( $logfile, '_tdb_put', $id, $data )
        unless $self->{-no_logging};

    return 1;
}


# delete a database record in TDB

sub _tdb_delete {
    my ( $self, $tdb, $id ) = @_;

    unless ( $self->{-no_transactions} ) {

        # start a transaction
        if ( !$tdb->tranbegin() ) {
            my $ecode = $tdb->ecode();
            my $err   = $tdb->errmsg($ecode);
            get_logger(__PACKAGE__)->error("delete error: $err\n");
            return 0;
        }
    }

    # get logfile for transaction
    my $logfile = $self->_get_logfile($tdb);

    # delete operation
    if ( !$tdb->out($id) ) {
        my $ecode = $tdb->ecode();
        my $err   = $tdb->errmsg($ecode);
        get_logger(__PACKAGE__)->error("delete error: $err\n");
        unless ( $self->{-no_transactions} ) {
            if ( !$tdb->tranabort() ) {
                my $ecode = $tdb->ecode();
                my $err   = $tdb->errmsg($ecode);
                get_logger(__PACKAGE__)->error("delete error: $err\n");
            }
        }
        return 0;
    }

    unless ( $self->{-no_transactions} ) {

        # commit transaction
        if ( !$tdb->trancommit() ) {
            my $ecode = $tdb->ecode();
            my $err   = $tdb->errmsg($ecode);
            get_logger(__PACKAGE__)->error("delete error: $err\n");
            return 0;
        }
    }

    # log transaction
    $self->_log_transaction( $logfile, '_tdb_delete', $id )
        unless $self->{-no_logging};

    return 1;
}


#-----------------------------------------------------------------
# backups and transaction logging
#-----------------------------------------------------------------

# get the name of the transaction logfile
# make a hotcopy of the current database if necessary
# (one per day every month)

sub _get_logfile {
    my ( $self, $tdb ) = @_;

    # get local time (for logfile name)
    my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime(time);
    my $database = $self->{-database};

    my $hotcopy  = $self->{-database} . '.' . $mday;
    my $translog = $hotcopy . '.log';

    # make a new copy if the file does not exist or is older than 27 days

    if ( ( !-e $hotcopy ) || ( -M $hotcopy > 27 ) ) {
        if ( !$tdb->copy($hotcopy) ) {
            my $ecode = $tdb->ecode();          # error code
            my $err   = $tdb->errmsg($ecode);
            get_logger(__PACKAGE__)->error("tdb error: $err\n");
        }
    }

    unless ( $self->{-no_logging} ) {
        if ( !-e $translog ) {
            if ( !open F, ">$translog" ) {
                get_logger(__PACKAGE__)->error("cannot write to $translog\n");
                return $translog;
            }
            print F '#!/usr/bin/perl',                           "\n\n";
            print F 'use lib $FindBin::Bin."/../lib";',          "\n";
            print F 'use LetsMT::Repository::DB::TokyoCabinet;', "\n\n";
            print F
                'my $db = new LetsMT::Repository::DB::TokyoCabinet(-no_logging => 1);',
                "\n";
            print F "\$db->open('$hotcopy');\n";
            print F "\$db->hotcopy('$hotcopy.recovered');\n";
            print F "\$db->close();\n";
            print F "\$db->open('$hotcopy.recovered');\n";
            print F "\$tdb=\$db->db_handle();\n\n";
        }
    }
    return $translog;
}

# log transaction as perl command in the transaction logfile

sub _log_transaction {
    my ( $self, $translog, $operation, $id, $data ) = @_;

    if ( !open F, ">>$translog" ) {
        get_logger(__PACKAGE__)->error("cannot write to $translog\n");
        return 0;
    }
    print F '$db->' . $operation . '($tdb,' . Dumper($id);
    print F ',', Dumper($data) if ($data);
    print F ");\n";
    close F;
    return 1;
}

# returns the output of the 'tctmgr inform' command with status information about the database

sub inform {
    my $self = shift;

    my $result_string = `tctmgr inform $self->{-database}`;

    my $result_hash = {};

    my @lines = split /\n/, $result_string;
    foreach my $line (@lines) {
        my @key_value = split( /:/, $line );
        get_logger(__PACKAGE__)->debug( Dumper(@key_value) );
        $key_value[1] =~ s/^\s+//;
        $result_hash->{ $key_value[0] }
            = [ ( $key_value[1] ne '' ) ? $key_value[1] : 'none' ];
    }

    return $result_hash;
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
