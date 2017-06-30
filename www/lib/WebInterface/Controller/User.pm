package WebInterface::Controller::User;

use strict;
use warnings;
use v5.10;

use open qw(:std :utf8);

use Mojo::Base 'Mojolicious::Controller';
use Digest::MD5 qw(md5_base64);
use Time::Local;
use POSIX qw(strftime);

use WebInterface::Model::User;
use LetsMT::WebService;

sub login {
    my $self = shift;

    my $user = $self->param('user') || '';
    my $pass = $self->param('pass') || '';

    my $result =
      WebInterface::Model::User->select( { username => $user } )->hash();

    if ( $user && $self->authenticate( $user, $pass ) ) {

       #if ( $result->{username} && $result->{password} eq md5_base64($pass) ) {
       #    $self->session(user => $result->{username});

        #$self->load_user($result->{username});

        # update login timestamp
        my $user_id = WebInterface::Model::User->update(
            { login_timestamp => time },
            { id              => $result->{'id'} },
        );
        $self->app->log->debug( 'user id' . $self->app->dumper($user_id) );

        my $login_message;
        if ( $result->{'login_timestamp'} ) {
            my $tm         = localtime( $result->{'login_timestamp'} );
            my $last_login = strftime( "%d-%m-%Y %H:%M:%S",
                localtime( $result->{'login_timestamp'} ) );
            $login_message = "Your last login was $last_login. ";
        }
        else {
            $login_message = "This is your first login. ";
        }

        $self->flash( message_info => "Thanks for logging in. $login_message",
        );
        $self->redirect_to('welcome');
    }
    elsif ($user) {
        $self->stash(
            message_error => 'Wrong name or password, please try again! ' );
    }
    else {
    }

    return;
}

sub logmeout {
    my $self = shift;

    $self->logout;

    #$self->session(expires => 1);

    $self->redirect_to('welcome');
}

# Loads a user
# TODO: dummy, implement real functionality!
sub load_user {
    my ( $self, $uid ) = @_;

    #$self->logger->debug( 'load_user called: replace dummy!'. $uid );

    my $user = {
        user            => $uid,
        username        => 'foo',
        login_timestamp => time,
    };

    return $user;
}

sub validate_user {
    my ( $self, $username, $password, $extradata ) = @_;

    #$self->logger->debug( 'validate_user called...'.$username );

    my $result =
      WebInterface::Model::User->select( { username => $username } )->hash();

    if ( $result->{username} && $result->{password} eq md5_base64($password) ) {

        #$self->logger->debug( 'success' );
        return $result->{username};
    }
    else {

        #$self->logger->debug( 'fail' );
        return undef;
    }
}

sub registration_check {
    my $self = shift;

    my $user  = $self->param('user');
    my $email = $self->param('email');
    my $pass1 = $self->param('pass1');
    my $pass2 = $self->param('pass2');
    my $code  = $self->param('code');

    # get captcha check from stash
    my $md5sum = $self->flash('md5sum') || 'none';

    my $err_msg;

    # Check form field input
  CHECK: {

        my $captcha = $self->captcha->check_code( $code, $md5sum );
        $self->logger->debug( 'result: ' . $captcha );

        unless ( $captcha == 1 ) {
            $err_msg = "Code didn't match!";
            last CHECK;
        }

        unless ( $user && $email && $pass1 && $pass2 && $code ) {
            $err_msg = 'Please fill in all fields!';
            last CHECK;
        }

        my $result =
          WebInterface::Model::User->select( { username => $user } )->hash();

        if ( $result->{user_id} ) {
            $err_msg = 'User exists already!';
            last CHECK;
        }

        unless ( &_check_email($email) ) {
            $err_msg = 'Invalid email!';
            last CHECK;
        }

        unless ( $pass1 eq $pass2 ) {
            $err_msg = "Passwords didn't match!";
            last CHECK;
        }

    }

    # if no error message so far, try to create user
    unless ( $err_msg || LetsMT::WebService::post_group( $user, undef, $user ) )
    {
        $err_msg .= 'Could not create user in repository!';
    }

    if ($err_msg) {
        $self->flash(
            message_error => $err_msg,
            user          => $user,
            email         => $email,
        )->redirect_to('register');

        return;
    }

# if no problem found -> write user data to database, log user in and redirect to welcome page and confirm registration

    # Save User
    my %user = (
        username => $user,
        password => md5_base64($pass1),
        email    => $email,
    );

    my $user_id = WebInterface::Model::User->insert( \%user );

    $self->session( user => $user );
    $self->flash(
        message_info => 'Thanks for registering. You are logged in now.' );
    $self->redirect_to('welcome');
}

sub register {
    my $self = shift;

    my $md5sum = $self->captcha->generate_code(5);

    die 'Could not generate captacha code!' unless $md5sum;

    $self->stash( md5sum => $md5sum );
    $self->flash( md5sum => $md5sum );

    return $self->render;
}

sub profile {
    my $self = shift;

    #get user data from DB
    my $user = $self->session('user');
    my $result =
      WebInterface::Model::User->select( { username => $user } )->hash();

    #prefil update form
    $self->stash( email => $result->{'email'}, );

    return;
}

sub update {
    my $self = shift;

    my $email      = $self->param('email');
    my $pass_old   = $self->param('pass_old');
    my $pass_new_1 = $self->param('pass_new_1');
    my $pass_new_2 = $self->param('pass_new_2');

    my $user = $self->session('user');
    my $err_msg;

  CHECK: {
        unless ( $email && $pass_old && $pass_new_1 && $pass_new_2 ) {
            $err_msg = 'Please fill in all fields!';
            last CHECK;
        }

        unless ( &_check_email($email) ) {
            $err_msg = 'Invalid email!';
            last CHECK;
        }

        unless ( $pass_new_1 eq $pass_new_2 ) {
            $err_msg = "New passwords didn't match!";
            last CHECK;
        }

        my $result =
          WebInterface::Model::User->select( { username => $user } )->hash();

        unless ( $result->{'password'} eq md5_base64($pass_old) ) {
            $err_msg = "Old password wrong!";
            last CHECK;
        }
    }

    if ($err_msg) {
        $self->flash(
            message_error => $err_msg,
            email         => $email,
        )->redirect_to('profile');

        return;
    }

    # user hash for update
    my %user_data = (
        password => md5_base64($pass_new_1),
        email    => $email,
    );

    my %where = ( username => $user, );

    my $user_id = WebInterface::Model::User->update( \%user_data, \%where );

    if ($user_id) {
        $self->flash( message_info => 'Your profile was updated!' );
        $self->redirect_to('welcome');
    }
    else {
        $self->flash(
            message_error => 'Error updating profile',
            email         => $email,
        )->redirect_to('profile');

        return;
    }

}

sub _check_email {
    my $email = shift;
    return (
        $email =~ '^[a-zA-Z]+(([\'\,\.\- ][a-zA-Z ])?[a-zA-Z]*)*\s+&lt;(\w[-._\w]*\w@\w[-._\w]*\w\.\w{2,3})&gt;$|^(\w[-._\w]*\w@\w[-._\w]*\w\.\w{2,3})$'
    );
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
