package LetsMT::Repository::Persist;

=head1 NAME

LetsMT::Repository::Persist - persistence layer between modules for object persistence and the underlying Persistent::MySQL

=cut

use strict;
use parent 'Persistent::MySQL';

use open qw(:std :utf8);

use DBI;

use Log::Log4perl qw(get_logger :levels);


=head1 CONSTRUCTOR

Does minimal blessing.

Returns: a Persistent::MySQL-derived object

=cut

sub new {
    my $class = shift;
    my $obj   = {};
    bless( $obj, $class );
    return $obj;
}


=head1 METHODS

=head2 C<initialize>

Initialize the instance by creating the table if necessary, and setting up the Persistence::MySQL-part.

Returns: nothing

=cut

sub initialize {
    my $self = shift;

    my $genspec = {
        db   => $ENV{DBNAME},
        port => $ENV{DBPORT},
        host => $ENV{DBHOST},
        user => $ENV{DBUSER},
        pwd  => $ENV{DBPASS}
    };

    my @ModParts = split( '::', ref($self) );
    $self->{table} = "sm_" . $ModParts[-1];

    ### try to create table if it does not exist
    unless ( $self->table_exists( $self->{table} ) ) {
        $self->{table_def} = "CREATE TABLE " . $self->{table} . " (\n";
        foreach my $key ( keys %{ $self->{fields} } ) {
            $self->{table_def}
                .= "       $key " . $self->{fields}->{$key}->{type} . ",\n";
        }
        $self->{table_def} .= "       PRIMARY KEY("
            . join( ',',
            grep { $self->{fields}->{$_}->{prim} } keys %{ $self->{fields} } )
            . "))";
        get_logger(__PACKAGE__)->info( $self->{table_def} );
        $self->create_table( $self->{table_def} );
    }

    ### bind to persistence
    eval {
        $self->SUPER::initialize(
            "DBI:mysql:database=$genspec->{db};host=$genspec->{host};mysql_socket=/tmp/mysql.sock",
            $genspec->{user}, $genspec->{pwd}, $self->{table} );
    };
    if ($@) {
        get_logger(__PACKAGE__)->error("creating table failed");
        exit 1;
    }

    ### initiate object
    foreach my $key ( keys %{ $self->{fields} } ) {
        my $val  = $self->{fields}->{$key};
        my $type = 'Persistent';
        $type = 'Identity'  if ( $val->{prim} );
        $type = 'Transient' if ( $val->{transient} );

        if ( $val->{type} =~ /^varchar\s*\(\s*(\d+)\s*\)/i ) {
            $self->add_attribute( $key, $type, 'VarChar', undef, $1 );
        }
        elsif ( $val->{type} =~ /^varchar/i ) {
            $self->add_attribute( $key, $type, 'VarChar', undef, 128 );
        }
        elsif ( $val->{type} =~ /^int/i ) {
            $self->add_attribute( $key, $type, 'Number', 2, 7 );
        }
        elsif ( $val->{type} =~ /^date/i ) {
            $self->add_attribute( $key, $type, 'DateTime', undef );
        }
    }
}


=head2 C<init_instance>

 &$persist->init_instance ($self, $query)

Stores an object in the store.

Returns: the instance object, or undef if it already existed.

=cut

sub init_instance {
    my $self  = shift;
    my $query = shift;

    my %attrs = @_;

    get_logger(__PACKAGE__)->info( "init " . ref($self) . " ($query)" );

    if ( $self->retrieve($query) ) {
        return undef;
    }

    return $self->store(%attrs);
}

sub make_idquery {
    die "make_idquery not implemented in base class!\n";
}


=head2 C<find>

=cut

sub find {
    my $self    = shift;
    my $idquery = $self->make_idquery(@_);
    my $status  = $self->retrieve(qq{$idquery});
    return $status ? $self : undef;
}


=head2 C<retrieve>

 &$persist->retrieve($self, $sql)

Retrieves an object from the data store.

Returns: true or false depending on whether there was such an object.

=cut

sub retrieve {
    my ( $self, $sql ) = @_;

    eval { $self->restore_where($sql); };
    print "An error occurred: $@\n" if $@;

    if ( $self->restore_next() ) {

        #get_logger(__PACKAGE__)->info("retrieve $sql GOOD");
        return 1;
    }

    #get_logger(__PACKAGE__)->info("retrieve $sql BAD");

    return 0;
}



=head2 C<store>

Persist the object to the datastore.

Returns: true or false

=cut

sub store {
    my $self  = shift;
    my %attrs = @_;

    eval {
        $self->clear;

        foreach my $attr ( keys %attrs ) {
            my $q = "";
            if ( defined( $attrs{$attr} ) ) {
                $q = '$self->' . $attr . "(\"" . $attrs{$attr} . "\")";
            }
            else {
                $q = '$self->' . $attr . "(undef)";
            }
            eval "$q";
        }
        $self->save;
    };
    if ($@) {
        print "An error occurred: $@\n";
        return 0;
    }

    return 1;
}


=head2 C<drop_all_content>

Clear the datastore.

Returns: nothing

=cut

sub drop_all_content {
    my $self = shift;

    eval {
        $self->restore_all();
        $self->delete while $self->restore_next();
    };
    print "An error occurred: $@\n" if $@;
}


=head2 C<create_table>

Creates the table in the database.

Returns: true or false

=cut

sub create_table {
    my $self = shift;

    $self->dosql( $self->{table_def} );
}



=head2 C<drop_table>

Drop the objects table.

Returns: true or false

=cut

sub drop_table {
    my $self = shift;

    get_logger(__PACKAGE__)->info("DROP TABLE $self->{table}");
    $self->dosql( "DROP TABLE IF EXISTS " . $self->{table} );
}



=head2 C<dosql>

 &$persist->dosql ($sql, $moreopts)

Execute an SQL statement.
C<$moreopts> may be used to control the DBI connection.

Returns: true or false

=cut

sub dosql {
    my $self     = shift;
    my $sql      = shift;
    my $moreopts = shift;
    my $dbh      = myconnect($moreopts);

    my $status = 0;
    if ($dbh) {
        get_logger(__PACKAGE__)->info("do: $sql");
        eval { $status = $dbh->do($sql); };
        $dbh->disconnect();
    }

    return $status;
}



=head2 C<myconnect>

 &$persist->myconnect ($moreopts)

Connects to the database using parameters from the environment (DBNAME, DBPORT, DBHOST, DBUSER, DBPASS).
C<$moreopts> may be used to control the DBI connection.

Returns: database handler object, or undef

=cut

sub myconnect {
    my $moreopts = shift;
    my $opts     = {
        AutoCommit => 1,
        RaiseError => 1,
        PrintError => 1,
    };

    my $genspec = {
        db   => $ENV{DBNAME},
        port => $ENV{DBPORT},
        host => $ENV{DBHOST},
        user => $ENV{DBUSER},
        pwd  => $ENV{DBPASS}
    };

    if ($moreopts) {
        map { $opts->{$_} = $moreopts->{$_} } keys %{$moreopts};
    }

    my $dbh = undef;
    eval {
        $dbh
            = DBI->connect(
            "DBI:mysql:database=$genspec->{db};host=$genspec->{host};mysql_socket=/tmp/mysql.sock",
            $genspec->{user}, $genspec->{pwd}, $opts );
    };

    return $dbh;
}



=head2 C<table_exists>

 table_exists ($table)

Check whether a table exists.

Returns: true or false

=cut

sub table_exists {
    my ( $self, $table ) = @_;
    my $dbh = myconnect();

    if ($dbh) {
        my @tabs = map { s/^.*\.//; s/`//g; $_ } $dbh->tables; # `
        my $exists = scalar( grep {/^$table$/} @tabs );
        $dbh->disconnect();
        return $exists;
    }
    return 0;
}


1;

