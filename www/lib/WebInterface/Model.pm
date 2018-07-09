package WebInterface::Model;

use strict;
use warnings;
use v5.10;

use DBIx::Simple;
use SQL::Abstract;
use Carp qw/croak/;
use Digest::MD5 qw(md5_base64);
use DBIx::DataSource qw( create_database drop_database );

use LetsMT::WebService;

use Mojo::Loader;

# Reloadable Model
my $modules = Mojo::Loader->find_modules('WebInterface::Model');
for my $module (@$modules) {
    Mojo::Loader->load_class($module)
}

my $DB;

sub init {
    my ($class, $config) = @_;
    #$class->logger->error( "No dsn was passed!") unless $config && $config->{dsn};

    unless ( $DB ) {

        # try to connect to DB, on failure try to create DB first
        unless ( eval {DBIx::Simple->connect(@$config{qw/dsn user password/})} ) {
            #$class->logger->debug( 'Could not connect to DB, trying to create it' );
            create_database(@$config{qw/dsn user password/})
                or warn $DBIx::DataSource::errstr;
        }

        $DB = DBIx::Simple->connect(@$config{qw/dsn user password/},
            {
                 RaiseError        => 1,
                 mysql_enable_utf8 => 1,
            } )  or die DBIx::Simple->error;

        $DB->abstract = SQL::Abstract->new(
               case          => 'lower',
               logic         => 'and',
               convert       => 'upper'
        );

        unless ( eval {$DB->select('user')} ) { # TODO make better check
            #$class->logger->warn( 'No user table found...trying to create it' );
            $class->create_db_structure(
                $config->{'system_user'},
                $config->{'system_password'},
            );
        }
    }

    return $DB;
}

sub db {
    return $DB if $DB;
    #$class->logger->warn( "You should init model first!" );
}

sub create_db_structure {
    my $class           = shift;
    my $system_user     = shift;
    my $system_password = shift;

    #$class->logger->info( 'Creating DB structure...' );

    $class->db->query(
            'CREATE TABLE IF NOT EXISTS user (id  INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
                username        VARCHAR(128) NOT NULL,
                password        VARCHAR(22) NOT NULL,
                email           VARCHAR(256),
                login_timestamp VARCHAR(20) DEFAULT 0,
                active          BOOL DEFAULT TRUE,
                admin           BOOL DEFAULT FALSE,
                UNIQUE (username));'
    );

    #add the system admin user to the mySQL database
    #$class->logger->info( 'Adding system user to mySQL DB...');
    my $pass = md5_base64( $system_password );
    $class->db->query(
        'INSERT INTO user(username, password, admin) VALUES("'.$system_user.'", "'.$pass.'", TRUE);'
    );

    #add system admin also to the group database
    #$class->logger->info('Adding system user to group DB...');
    my $result = LetsMT::WebService::post_group( $system_user, undef, $system_user );
    #$class->logger->info('failed' unless ( $result ));
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
