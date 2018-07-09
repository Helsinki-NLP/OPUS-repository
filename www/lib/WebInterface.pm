package WebInterface;

# use strict;
use warnings;

use open qw(:std :utf8);

use Net::SSL;

use Mojo::Base 'Mojolicious';
use Authen::Captcha;
use Mojolicious::Plugin::Authentication;
use WebInterface::Controller::User;
use WebInterface::Model;
use Mojo::Log;

use Log::Log4perl qw(get_logger :levels);

# This method will run once at server start
sub startup {
    my $self = shift;

#    $self->hook('before_dispatch' => sub {
#        my $self = shift;
#
#        if ($self->req->headers->header('X-Forwarded-Host')) {
#            ### Proxy Path setting ###
#            my $path = '/grenzschnitte';
#
#            $self->req->url->base->path->parse($path);
#        }
#    });

    # Setup the config file web_interface.json
    my $config = $self->plugin('JSONConfig');

    $self->secrets(['JkdjUOje74KJDh209']);
    # $self->mode('development');
    $self->mode('deployment');
    $self->sessions->default_expiration(86400); #one day

    # Initiate Log4perl by loading conf file and reload if it changes every 60 sec
#    Log::Log4perl->init_and_watch( $ENV{LOG4PERLCONF}, 60 );
#    get_logger("LetsMT")->info("initiated Log4perl from $ENV{LOG4PERLCONF}");

    #Get the logger
    my $log = Mojo::Log->new(path => $ENV{LETSMTLOG_DIR}.'/grenzschnitte.log', level => 'debug');
    $self->helper(logger => sub { return $log });

    $self->helper(system_user => sub {return $self->config->{'system_user'}});

    # Load and init Model
    Mojo::Loader->load_class('WebInterface::Model');

    print STDERR $self->config->{'db-password'};
    WebInterface::Model->init( #$config->{db} ||
        {
        dsn             => 'dbi:mysql:database=webinterface_user_db',
        user            => $self->config->{'db_user'},       #database user
        password        => $self->config->{'db_password'},   #database password
        system_user     => $self->config->{'system_user'},   #system user, used when no user is logged in
        system_password => $self->config->{'db_password'},   #password of system user, TODO: change befor deployment!
    });

    # Set up authentication
    $self->plugin('authentication' => {
        'autoload_user'   => 1,
        'session_key'     => 'user',
        'load_user'       => sub { return &WebInterface::Controller::User::load_user(@_); },
        'validate_user'   => sub { return &WebInterface::Controller::User::validate_user(@_); },
        #'current_user_fn' => 'user', # compatibility with old code
    });

    #Set up captcha for user registration
    $self->helper(captcha => sub {
        return new Authen::Captcha (
            data_folder   => $ENV{LETSMT_TMP} || '/tmp',  #$self->home->rel_dir('tmp'),
            output_folder => $self->home->rel_file('public'),
            debug         => 0,
        )
    });

    my $r = $self->routes;
    $r->namespaces(['WebInterface::Controller']);

    # Bridge to check login status of user
    # all routes based on this are only accessible for users that are logged in
    my $check = $r->route('/')->to(cb => sub {
        my $self = shift;

        unless ( $self->is_user_authenticated ) {
            $self->flash( message_info => 'You are not logged in!');
            $self->logger->debug( 'you are NOT authenticated!' );
            $self->redirect_to('welcome');
            return 0;
        }
        return 1;
    });


    # Routes
    $r    ->get('/')                                 ->to('welcome#index')->name('welcome');
    $check->get('/index')                            ->to('welcome#index')->name('index');
    $check->get('/protected')                        ->to('welcome#protected')->name('protected');
    $r    ->get('/get_details/:slot/:branch/*path')  ->to('welcome#get_details', slot => '', branch => '', path => '')->name('get_details');

    # User
    $r    ->any('/login')             ->to('user#login')->name('login');
    $r    ->get('/logmeout')          ->to('user#logmeout')->name('logmeout');
    $r    ->any('/register')          ->to('user#register')->name('register');
    $r    ->any('/registration_check')->to('user#registration_check')->name('registration_check');
    $check->any('/profile')           ->to('user#profile')->name('profile');
    $check->post('/update')           ->to('user#update')->name('update');

    # Storage
    $r    ->get('/show/:slot/:branch/*path')           ->to('storage#show',                 slot => '', branch => '', path => '')->name('show');
    $r    ->get('/cat_content/:slot/:branch/*path')    ->to('storage#ajax_cat_content',     slot => '', branch => '', path => '')->name('cat_content');
    $r    ->get('/cat_content_raw/:slot/:branch/*path')->to('storage#ajax_cat_content_raw', slot => '', branch => '', path => '')->name('cat_content_raw');
    $r    ->get('/get_tab_list')                       ->to('storage#ajax_get_tab_list')->name('get_tab_list');
    $r    ->get('/get_revision_dropdown')              ->to('storage#ajax_get_revision_dropdown', slot => '', branch => '', path => '')->name('get_revision_dropdown');
    $check->any('/upload/:slot/:branch/*path')         ->to('storage#upload',               slot => '', branch => '', path => '')->name('upload');
    $check->any('/add_corpus')                         ->to('storage#add_corpus')                                                ->name('add_corpus');
    $check->any('/delete/:slot/:branch/*path')         ->to('storage#delete',               slot => '', branch => '', path => '')->name('delete');
    $r    ->get('/download/:slot/:branch/*path')       ->to('storage#download',             slot => '', branch => '', path => '')->name('download');
    $check->get('/clone/:slot/:branch/*path')          ->to('storage#clone',                slot => '', branch => '', path => '')->name('clone');
    $check->any('/realign/:slot/:branch/*path')        ->to('storage#realign',              slot => '', branch => '', path => '')->name('realign');
    $check->any('/import/:slot/:branch/*path')         ->to('storage#import',               slot => '', branch => '', path => '')->name('import');

    # Metadata
    $r    ->get('/metadata/:slot/:branch/*path')      ->to('metadata#ajax_show',               slot => '', branch => '', path => '')->name('metadata');
    $r    ->get('/import_status/:slot/:branch/*path') ->to('metadata#ajax_show_import_status', slot => '', branch => '', path => '')->name('import_status');
    $r    ->get('/language_count/:slot/:branch/*path')->to('metadata#language_count',          slot => '', branch => '', path => '')->name('language_count');
    $check->any('/edit/:slot/:branch/*rr_path')       ->to('metadata#edit',                    slot => '', branch => '', rr_path => '')->name('edit');


    $r->get('/tools')->to('tools#index');

    $r->get('/error')->to('error#index');

    $r->any('/filebrowser/:slot/:branch/*path')->to('filebrowser#list',           slot => '', branch => '', path => '')->name('filebrowser');
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
