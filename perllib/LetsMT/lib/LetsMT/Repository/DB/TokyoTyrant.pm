package LetsMT::Repository::DB::TokyoTyrant;

=head1 NAME

LetsMT::Repository::DB::TokyoTyrant - a module for storing and manipulating metadata

=head1 DESCRIPTION

Tokyo Tyrant provides a network interface to the Tokyo Cabinet DBM.

=cut

# derive methods from TokyoCabinet
# IMPORTANT: overwrite constructor!

use strict;
use parent 'LetsMT::Repository::DB::TokyoCabinet';

use open qw(:std :utf8);
use Encode qw(decode);

use TokyoTyrant;
use Time::HiRes qw (time);

use Data::Dumper;
use Log::Log4perl qw(get_logger :levels);
use LetsMT::Repository::Err;

$Data::Dumper::Terse  = 1;    # don't output names where feasible
$Data::Dumper::Indent = 0;    # save space (no pretty printing)

# $Data::Dumper::Indent = 1;     # readable output (but not too fancy)
# $Data::Dumper::Indent = 2;     # full indentation (default in Data::Dumper)

our $STARTOPTIMIZE_SIZE = 500000000;    # try to optimize if filesize > 500MB


=head1 CONSTRUCTOR

 $metaDB = new LetsMT::Repository::DB::TokyoTyrant ( -host => $hostname, -port => $port )

=cut

# constructor arguments:
#
# -host ....... host name of TokyoTyrant server
# -port ....... port number of DB instance

sub new {
    my $class = shift;
    my %attr  = @_;

    my $self = {};
    bless $self, $class;

    foreach ( keys %attr ) {
        $self->{$_} = $attr{$_};
    }

    # create the TDB object
    $self->{TDB} = TokyoTyrant::RDBTBL->new();

    if ( not defined $self->{-host} ) {
        get_logger(__PACKAGE__)->fatal('TokyoTyrant host not defined');
    }

    if ( not defined $self->{-port} ) {
        get_logger(__PACKAGE__)->fatal('TokyoTyrant port not defined');
    }

    return $self;
}


=head1 DESTRUCTOR

Make sure that the DB gets closed again.

=cut

DESTROY {
    my $self = shift;
    $self->close();
}


=head1 METHODS

=head2 C<open>

 $metaDB->open
 # or:
 $metaDB->open ( -host => $hostname, -port => $port )

=cut

sub open {
    my $self = shift;
    my $host = shift || $self->{-host};
    my $port = shift || $self->{-port};
    my $tdb  = $self->{TDB};

    if ( !$tdb->open( $host, $port ) ) {
        my $ecode = $tdb->ecode();    # error code
        get_logger(__PACKAGE__)
            ->fatal( 'DB open error' . $tdb->errmsg($ecode) );
        raise( 7, 'could not open database for read access', 'fatal' );
        return 0;
    }

    $self->{OPEN} = 1;
    return 1;
}


=head2 C<open_read>

=cut

sub open_read {
    my $self = shift;
    return $self->open(@_);
}


=head2 C<open_write>

=cut

sub open_write {
    my $self = shift;
    return $self->open(@_);
}


=head2 C<hotcopy>

** Not implemented. **

=cut

sub hotcopy {
    get_logger(__PACKAGE__)->info('not implemented');
}


=head2 C<db_handle>

=cut

sub db_handle {
    return $_[0]->{TDB};
}


=head2 C<auto_optimize>

** Not implemented. **

=cut

sub auto_optimize {
    get_logger(__PACKAGE__)->info('not implemented');
}


=head2 C<optimize>

** Not implemented. **

=cut

sub optimize {
    get_logger(__PACKAGE__)->info('not implemented');
}


=head2 C<copy>

 $metaDB->copy ($oldprefix, $newprefix [, $uid])

Copy all metadata records for IDs with a specific prefix
to new records, with the old prefix replaced by a new one.
(This is useful when copying branches!)

Optional parameter C<$uid>: set new uid for all copied elements.

=cut

sub copy {
    my ( $self, $oldpref, $newpref, $uid ) = @_;
    my $tdb = $self->{TDB};

    return 0 if ( not defined $oldpref );
    return 0 if ( not defined $newpref );

    my $qry = TokyoTyrant::RDBQRY->new($tdb);
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


#----------------------------------------------------------------------

=head2 C<search>

Query the database with simple conditions (conjunction only!).
Special treatment for fields that start with:

   ONE_OF_ ....... use keyword search in a string (OR)
   ALL_OF_ ....... use keyword search in a string (AND)
   STARTS_WITH_ .. search prefix
   ENDS_WITH_ .... search suffix
   MIN_ .......... numeric comparison (>=)
   MAX_ .......... numeric comparison (<=)

=cut

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# WARNING: no type check here!!!!
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

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
    my $qry = TokyoTyrant::RDBQRY->new($tdb);

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


=head2 C<delete_recursive>

 $metaDB->delete_recursive ($prefix)

Delete recursive for all resource items below path (dangerous!).

If C<$prefix> ends with '/', delete only sub-resources.
Otherwise also delete resource C<$prefix> (together with all sub-resources).

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
    my $qry   = TokyoTyrant::RDBQRY->new($tdb);
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


=head2 C<do_recursive>

 $metaDB->do_recursive ($method, $path, $data)

Add metadata recursively to all records below the given path.

=cut

sub do_recursive {
    my ( $self, $method, $path, $data ) = @_;
    my $tdb = $self->{TDB};

    return 0 if ( not defined $path );    # we need to have a prefix!

    # add '/' at the end to avoid substring matches
    # (for example prefix='/my/path' would also match '/my/pathos/...')
    my $prefix = $path;
    $prefix .= '/' if ( $path !~ /\/$/ );

    my $count = 0;
    my $qry   = TokyoTyrant::RDBQRY->new($tdb);
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


#----------------------------------------------------------------------------
# interaction with TDB: write and delete transactions
#----------------------------------------------------------------------------

=head1 INTERNAL METHODS

=head2 C<_tdb_put>

 $self->_tdb_put ($tdb, $id, $data)

=cut

sub _tdb_put {
    my ( $self, $tdb, $id, $data ) = @_;

    # try to put the data record into the database
    # always add key '_ID_' as one of the fields!

    $data->{_ID_} = $id;
    if ( !$tdb->put( $id, $data ) ) {
        my $ecode = $tdb->ecode();
        my $err   = $tdb->errmsg($ecode);
        get_logger(__PACKAGE__)->error("put error: $err\n");

        #printf STDERR ( "put error: %s\n", $tdb->errmsg($ecode) );
        delete $data->{_ID_};
        return 0;
    }
    delete $data->{_ID_};

    return 1;
}


=head2 C<_tdb_delete>

 $self->_tdb_delete ($tdb, $id)

=cut

# delete a database record in TDB

sub _tdb_delete {
    my ( $self, $tdb, $id ) = @_;

    # delete operation
    if ( !$tdb->out($id) ) {
        my $ecode = $tdb->ecode();

        #printf STDERR ( "tdb error: %s\n", $tdb->errmsg($ecode) );
        my $err = $tdb->errmsg($ecode);
        get_logger(__PACKAGE__)->error("delete error: $err\n");

        return 0;
    }

    return 1;
}


=head2 C<inform>

Returns the output of the 'tcrmgr inform' command with status information about the database.

=cut

sub inform {
    my $self = shift;

    my $result_string = `tcrmgr inform $self->{-database}`;

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
