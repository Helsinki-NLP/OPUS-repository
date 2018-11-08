package LetsMT::Repository::API::Job;

=head1 NAME

LetsMT::Repository::API::Job - API class for the REST URI C<job>

=head1 SYNOPSIS

 use LetsMT::Repository::API::Job;

 my $job = LetsMT::Repository::API::Job;
 $job->new($r);
 $job->process;

=head1 DESCRIPTION

This class implements the functionality available through the REST URI
C<job> - GET, PUT, POST and DELETE - and returns the result as a XML string.

=cut

use strict;
use parent 'LetsMT::Repository::API';

use open qw(:std :utf8);

use IO::Socket;

use Log::Log4perl qw(get_logger :levels);
use LetsMT::Repository::Err;
use Data::Dumper;

use LetsMT::Repository::Result;
use LetsMT::Repository::JobManager;


### CLASS METHOD ############################################################
# Usage      : LetsMT::Repository::API::Job->new($r);
# Purpose    : Constructor, creates an instance of API::Job class
# Returns    : Blessed hash_ref inherriting from LetsMT::Repository::API
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

Get a job description.

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::API::Job->get();
# Purpose    :
# Returns    : The result of the request as XML string
# Parameters : none
# Throws     : no exceptions
# Comments   : Overwrites get method from parent

sub get {
    my $self = shift;

    my $message = undef;

    get_logger(__PACKAGE__)->debug('job '.$self->{path_elements});

    ## no path? --> list all jobs
    unless (@{$self->{path_elements}}){
	my $result = LetsMT::Repository::JobManager::get_job_list();
	my $result_obj = LetsMT::Repository::Result->new(
	    type      => 'ok',
	    code      => 0,
	    operation => 'GET',
	    location  => 'job',
	    lists     => \$result,
	    message   => $message,
	    );
	return $result_obj->get_xml_result();
    }

    # Get status
    LetsMT::Repository::JobManager::check_status(
        message => \$message,
        path    => $self->{path_elements},
    );

    # Get training chart

    # Success if we got here, prepare Result object and return it
    my $result_obj = LetsMT::Repository::Result->new(
        type      => 'ok',
        code      => 0,
        operation => 'GET',
        location  => $self->{path_info},
        message   => $message,
    );

    return $result_obj->get_xml_result();
}


=head2 C<put>

Add or overwrite a job description.

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::API::Job->put();
# Purpose    : Submitts or overwrites a job description
# Returns    : The result of the request as XML string
# Parameters : none
# Throws     : no exceptions
# Comments   : Overwrites put method from parent

sub put {
    my $self = shift;

    my $message = undef;

    ## TODO: if a job ID is given instead for a path:
    ##       find the corresponding job description file from the metadata
    ##       and re-submit the job!

    if (exists $self->{args}->{run}){
	$message = LetsMT::Repository::JobManager::submit_job(
	    $self->{args}->{run},
	    $self->{path_elements},
	    $self->{args});
    }
    else{

        #delete existing meta?
        #try to delete job in case it exists already
        my $delete_message = undef;
        LetsMT::Repository::JobManager::delete(
            message => \$delete_message,
            path    => $self->{path_elements},
            );

        #resubmit job
        LetsMT::Repository::JobManager::submit(
            message => \$message,
            path    => join( '/', @{ $self->{path_elements} } ),
            uid     => $self->{args}->{uid},
            );
    }

    # Success if we got here, prepare Result object and return it
    my $result_obj = LetsMT::Repository::Result->new(
        type      => 'ok',
        code      => 0,
        operation => 'PUT',
        location  => $self->{path_info},
        message   => $message,
    );

    return $result_obj->get_xml_result();
}


=head2 C<post>

Submit a new job description.

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::API::Job->post();
# Purpose    : Submits a new job description
# Returns    : The result of the request as XML string
# Parameters : none
# Throws     : no exceptions
# Comments   : Overwrites post method from parent

sub post {
    my $self = shift;

    # check if running or already finished -> block?
    my $message = undef;

    #submit job
    LetsMT::Repository::JobManager::submit(
        message => \$message,
        path    => join( '/', @{ $self->{path_elements} } ),
        uid     => $self->{args}->{uid},
    );

    # Success if we got here, prepare Result object and return it
    my $result_obj = new LetsMT::Repository::Result(
        type      => 'ok',
        code      => 0,
        operation => 'POST',
        location  => $self->{path_info},
        message   => $message,
    );

    return $result_obj->get_xml_result();
}


=head2 C<delete>

Delete a running or scheduled job.

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::API::Job->delete();
# Purpose    : Delete a running or scheduled job
# Returns    : The result of the request as XML string
# Parameters : none
# Throws     : no exceptions
# Comments   : Overwrites delete method from parent

sub delete {
    my $self = shift;

    my $message = undef;

    ## TODO: if a job ID is given instead for a path:
    ##       find the corresponding job description file from the metadata
    ##       and delete the job!


    #delete job
    LetsMT::Repository::JobManager::delete(
        message => \$message,
        path    => $self->{path_elements},
	job_id  => $self->{args}->{job_id}
    );

    # Success if we got here, prepare Result object and return it
    my $result_obj = LetsMT::Repository::Result->new(
        type      => 'ok',
        code      => 0,
        operation => 'DELETE',
        location  => $self->{path_info},
        message   => '',
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
