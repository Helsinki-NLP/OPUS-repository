#-*-perl-*-

package LetsMT::Repository::API::Admin;

=head1 NAME

LetsMT::Repository::API::Admin - API class for the REST URI C<admin>

=head1 SYNOPSIS

 use LetsMT::Repository::API::Admin;

 my $admin = LetsMT::Repository::API::Admin;
 $admin->new($r);
 $admin->process;

=head1 DESCRIPTION

This class implements the functionality available through the REST URI
C<admin> - GET, POST and DELETE - and returns the result as an XML string.

=cut

use strict;
use parent 'LetsMT::Repository::API';

use open qw(:std :utf8);

use LetsMT::Repository::AdminManager;

use Log::Log4perl qw(get_logger :levels);
use LetsMT::Repository::Err;
use Data::Dumper;

use LetsMT::Repository::Result;


### CLASS METHOD ############################################################
# Usage      : LetsMT::Repository::API::Admin->new($r);
# Purpose    : Constructor, creates an instance of API::Admin class
# Returns    : Blessed hash_ref inheriting from LetsMT::Repository::API
# Parameters : hash_ref storing details from the mod_perl request
# Throws     : no exceptions
# Comments   : Overwrites constructor/factory method from parent

sub new {
    my ( $class, $r_ref ) = @_;
    #get_logger(__PACKAGE__)->debug( Dumper($r_ref) );
    bless $r_ref, $class;
}


=head1 METHODS

=head2 C<get>

Get the full SVN path to a given resource.

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::API::Admin->get();
# Purpose    : returns the full SVN path to a given resource
# Returns    : The result of the request as XML string
# Parameters : none
# Throws     : no exceptions
# Comments   : Overwrites get method from parent

sub get {
    my $self = shift;

    my $result = undef;

    if ( exists $self->{args}->{type} && $self->{args}->{type} eq 'svnpath' ) {
        my $elems = $self->{path_elements};
        my $slot  = shift(@$elems);

        &LetsMT::Repository::AdminManager::svnpath(
            \$result, $slot,
            join( '/', @$elems ),
        );
    }
    elsif ( exists $self->{args}->{type} && $self->{args}->{type} eq 'db_status' )  {
        &LetsMT::Repository::AdminManager::db_status( \$result, );
    }
    else {
        raise( 17, "or missing argument", 'warn' );
    }

    # Success if we got here, prepare Result object and return it
    my $result_obj = LetsMT::Repository::Result->new(
        type      => 'ok',
        code      => 0,
        operation => 'GET',
        location  => $self->{path_info},
        lists     => \$result,
    );

    return $result_obj->get_xml_result();
}


=head2 C<delete>

Delete a user in a group, or the whole group.

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::API::Admin->delete();
# Purpose    : Delete a user in a group or the whole group
# Returns    : The result of the request as XML string
# Parameters : none
# Throws     : no exceptions
# Comments   : Overwrites delete method from parent

sub delete {
    my $self = shift;

    my $message   = undef;
    my $user_name = $self->{path_elements}[0];

    if ( exists $self->{args}->{type} && $self->{args}->{type} eq 'user' ) {
        &LetsMT::Repository::GroupManager::delete_user_recursive(
            \$message, $user_name, );

    }
    else {
        raise( 17, "or missing argument", 'warn' );
    }

    # Success if we got here, prepare Result object and return it
    my $result_obj = LetsMT::Repository::Result->new(
        type      => 'ok',
        code      => 0,
        operation => 'DELETE',
        location  => $self->{path_info},
        message   => $message,
    );

    return $result_obj->get_xml_result();
}



=head2 C<put>


=cut


# admin/meta/optimize/fieldname
# admin/meta/index/add/fieldname/indextype
# admin/meta/index/delete/fieldname
# admin/meta/index/optimize/fieldname


sub put {
    my $self = shift;

    my $result = undef;
    my $elems = $self->{path_elements};

    my $app = shift(@$elems);

    #-------------------------------
    # administrate the metadata DB
    #-------------------------------

    if ($app eq 'meta'){
	my $fct = shift(@$elems);

	# do something with a field index
	if ($fct eq 'index'){
	    my $subfct = shift(@$elems);

	    $self->{args}->{name} = shift(@$elems);

	    if ($subfct eq 'add'){
		$self->{args}->{type} = shift(@$elems) unless (exists $self->{args}->{type});
	    }

	    &LetsMT::Repository::AdminManager::meta_db( \$result, 
							$subfct.'_index',
							%{$self->{args}} );
	}

	# optimize the database
	elsif ($fct eq 'optimize'){
	    &LetsMT::Repository::AdminManager::meta_db(\$result,'optimize',%{$self->{args}});
	}
	else {
	    raise( 17, "or missing argument", 'warn' );
	}
    }	
    else {
        raise( 17, "or missing argument", 'warn' );
    }

    # Success if we got here, prepare Result object and return it
    my $result_obj = LetsMT::Repository::Result->new(
        type      => 'ok',
        code      => 0,
        operation => 'PUT',
        location  => $self->{path_info},
        message   => $result,
    );

    return $result_obj->get_xml_result();
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
