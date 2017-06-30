package WebInterface::Controller::Storage;

use utf8;

use open qw(:std :utf8);

use warnings;
use strict;

use open qw(:std :utf8);

use Devel::Size qw(size total_size);
use Mojo::Upload;
use Mojo::Asset::File;
use Mojolicious::Static;
use File::Basename;
use File::Spec;
use JSON;
use Data::Dumper;
use File::Temp qw/ tempfile tempdir /;
use Locale::Language;

use Mojo::Base 'Mojolicious::Controller';

use Encode::Escape::Unicode;
use HTML::Entities;
use URI::Escape;
use Encode qw/is_utf8 decode encode decode_utf8/;

use WebInterface::Model::Storage;
use WebInterface::Model::Meta;

use LetsMT::WebService;
use LetsMT::Resource;
use LetsMT::Import;

###############################################################################
# Show action
# sets only some stash variables, the actual tab panels and the file browser
# are loaded via javascript in the template
###############################################################################
sub show {
    my $self = shift;

    ### Get path elements
    my $slot    = $self->stash('slot');
    my $branch  = $self->stash('branch');
    my $rc_path = $self->stash('path');

    $self->logger->debug( 'slot: ' . $slot );
    $self->logger->debug( 'branch: ' . $branch );
    $self->logger->debug( 'rc_path: ' . $rc_path );

    #we want only the directory part
    ( my $volume, $rc_path, my $file ) = File::Spec->splitpath($rc_path);

    #$self->logger->debug('rc_path: '.$rc_path);

    $self->stash(
        slot    => $slot,
        branch  => $branch,
        rc_path => $rc_path,    #name 'path' is reserved stash variable
        rev     => \(),
    );

    $self->render;
}

###############################################################################
# Ajax get a json encoded list of tabs for aux files
###############################################################################
sub ajax_get_tab_list {
    my $self = shift;
    my $path = $self->param('path');
    my $rev  = $self->param('rev') || 'HEAD';

    $self->logger->debug( 'get_tab_list: pathZ '
          . ( is_utf8($path) ? '1' : '0' ) . ': '
          . $path
          . ', REV:'
          . $rev );

    my @tab_list =
      $rev eq 'HEAD'
      ? { name => 'Meta Data', url => $self->url_for('metadata') . '/' . $path }
      : {
        name => 'Meta Data',
        url  => $self->url_for('metadata') . '/' . $path . '?rev=' . $rev
      };

    my $parts = ( Mojo::Path->new( $self->req->url->clone ) )->parts;

    my $file_name = pop @$parts;

    # decide based on file extention if
    # a raw version of the file should be shown
    # and if the content should be shown at all, e.g. zip/tar
    my @raw_list     = qw/xml tmx/;
    my @no_show_list = qw/zip gz tar tgz doc docx pdf/;
    if ($file_name) {
        my @file_name_parts =
          split( /\./, $file_name );    #TODO: not so secure with split?
        my $ext = pop @file_name_parts;

        if ( grep { $_ eq $ext } @raw_list ) {
            push(
                @tab_list,
                {
                    name => 'Raw',
                    url  => $self->url_for('cat_content_raw') . '/' 
                      . $path . '?rev='
                      . $rev
                }
            );
        }

        if ( grep { $_ eq $ext } @no_show_list ) {
            $self->stash( message_info =>
                  'Can not display content of files with this extention', );
        }
        else {
            push(
                @tab_list,
                {
                    name => 'Content',
                    url  => $self->url_for('cat_content') . '/' 
                      . $path . '?rev='
                      . $rev
                }
            );
        }
    }

    # check if import log and job files exist to this file
    my $path_to_file = dirname($path);

    my $list_result =
      WebInterface::Model::Storage->get_from_path( $path_to_file,
        $self->session('user') || $self->config->{'system_user'},
      );

    my $dom = Mojo::DOM->new($list_result);
    for my $entry ( $dom->find('entry')->each ) {
        if (   $entry->{'kind'} eq 'file'
            && $entry->name->text =~ /^$file_name\./
            && $entry->size->text > 0 )
        {

            #Set more user friendly name for log and job files
            #and load extra meta data where usefull
            my $name = '';
            if ( $entry->name->text =~ /\.import_job$/ ) {
                $name = 'Import Job';

            }
            elsif ( $entry->name->text =~ /\.import_job_err_[0-9]*/ ) {
                $name = 'Errors';
            }
            elsif ( $entry->name->text =~ /\.import_job_out_[0-9]*/ ) {
                $name = 'Output';
            }
            if ($name) {
                push(
                    @tab_list,
                    {
                        'name' => $name,
                        'url'  => '/cat_content_raw/'
                          . $path_to_file . '/'
                          . $entry->name->text . '?rev='
                          . $rev,
                    }
                );
            }
        }
    }

    my $json = to_json( \@tab_list, { utf8 => 1 } );

    $self->logger->debug( 'get_tab_list: '
          . @tab_list[0]->{url} . ' '
          . ( is_utf8( @tab_list[0]->{url} ) ? '1' : '0' ) . ': '
          . $json );

    $self->render( data => $json );
}

###############################################################################
# Ajax getter for html code to build the revision dropdown
###############################################################################
sub ajax_get_revision_dropdown {
    my $self = shift;
    my $path = $self->param('path');
    my $rev  = $self->param('rev') || 'HEAD';
    my $user = $self->session('user') || $self->config->{'system_user'};

    my $dropdown;

    # Get the revision history
    my $rev_array = &_get_revision_array( $self, $path, $rev );

   # if revision array contains only one rev (HEAD), we don't need to display it
   # and can stop here
    unless ( scalar @$rev_array > 1 ) {
        $dropdown .= "<option>none</option>\n";
        $self->render( data => $dropdown );
        return;
    }

    # Otherwise we go through the array and set the links and revs
    foreach my $revision (@$rev_array) {
        $dropdown .=
            "<option "
          . "link='$path' "
          . "rev='$revision->{'value'}' "
          . $revision->{'selected'} . " >"
          . $revision->{'value'}
          . "</option>\n";
    }

    #$self->logger->debug( $dropdown );

    $self->render( data => $dropdown );
}

###############################################################################
# Download action
###############################################################################
sub download {
    my $self = shift;

    my $slot   = $self->stash('slot');
    my $branch = $self->stash('branch');
    my $path   = $self->stash('path');
    my $user   = $self->session('user') || $self->config->{'system_user'};

    my $file =
      WebInterface::Model::Storage->download( $self->stash('slot'),
        $self->stash('branch'),
        $self->stash('path'), $user, );

    if ($file) {

        #$self->logger->debug( 'file name for downlaod: '. $file );

        my ( $filename, $directories, $suffix ) =
          fileparse( $file, qr/\.[^.]*/ );

        #$self->logger->debug( 'file size: '. -s $file );
        #$self->logger->debug( 'dir: '.$directories );
        #$self->logger->debug( 'filename: '. $filename.$suffix );

        my $static = Mojolicious::Static->new;
        $static->paths( [$directories] );
        $self->res->headers->content_type('zip');
        $self->res->headers->content_disposition(
            qq{attatchment; filename=$filename$suffix} );
        my $success = $static->serve( $self, $filename . $suffix );

        #$self->logger->debug( 'success: '.$success );
        $self->rendered;

    }
    else {
        return 0;
    }
}

###############################################################################
# Clone/copy a slot
###############################################################################
sub clone {
    my $self   = shift;
    my $slot   = $self->stash('slot');
    my $branch = $self->stash('branch');

    my $user = $self->session('user') || $self->config->{'system_user'};
    my $rev = $self->param('rev') || '';    #not used yet

    # Check if user already has a copy of that corpus
    my $meta = new WebInterface::Model::Meta->get(
        $slot,                              #slot
        $user,                              #branch
        undef,                              #path
        $user,                              #uid
    );

    my $dom = Mojo::DOM->new($meta);
    if ( $dom->at('entry') ) {
        $self->flash(
            message_error => 'You already have a copy of that corpus!' );
        $self->redirect_to( '/?open=' . $slot . '_' . $branch );
    }

    # Otherwise make a copy
    my $resource = new LetsMT::Resource(
        slot => $slot,
        user => $branch,
    );

    my $result = LetsMT::WebService::copy(
        $resource,
        $user,
        $user,    #destination/target of clone
        $rev,
    );

    if ($result) {
        $self->flash( message_info => "Successfully cloned corpus '$slot'", );
        $self->redirect_to( '/?open=' . $slot . '_' . $user );
    }
    else {
        $self->flash( message_error => 'Error cloning corpus!' );
        $self->redirect_to( '/?open=' . $slot . '_' . $branch );
    }
}

###############################################################################
# Ajax cat action
###############################################################################
sub ajax_cat_content {
    my $self   = shift;
    my $slot   = $self->stash('slot');
    my $branch = $self->stash('branch');
    my $path   = $self->stash('path');
    my $user   = $self->session('user') || $self->config->{'system_user'};
    my $from   = $self->param('from') || 0;
    my $to     = $self->param('to') || 50;
    my $rev    = $self->param('rev') || 'HEAD';

    # not used anymore?
    # Get a listing of the resource to get the revision history
    #my $rev_array = &_get_revision_array($self, $path, $rev);

    my $content =
      WebInterface::Model::Storage->cat( $self->stash('slot'),
        $self->stash('branch'),
        $self->stash('path'), $user, $from, $to, $rev, );

    $self->stash(
        aligned_content => '',                                  #needs to be set
        reload_link     => $self->url_for('cat_content') . '/' 
          . $slot . '/'
          . $branch . '/'
          . $path,
        from => $from,
        to   => $to,
        rev  => $rev,
    );

    ### Check document type
    my $dom_content = Mojo::DOM->new($content);

    if ($dom_content) {
        if ( $dom_content->at('cesAlign') ) {
            my $fromDoc = $dom_content->at('linkGrp')->attrs('fromDoc');
            my $toDoc   = $dom_content->at('linkGrp')->attrs('toDoc');

            #$self->logger->debug( 'fromDoc: ' . $fromDoc );
            #$self->logger->debug( 'toDoc: ' . $toDoc );

            if ( $fromDoc && $toDoc ) {
                my $aligned_content =
                  &_aligned_view( $self, $fromDoc, $toDoc,
                    decode_entities($content),
                    $from, $to );
                $self->stash(
                    aligned_content => $aligned_content,
                    fromDoc         => $fromDoc,
                    toDoc           => $toDoc,
                );
            }
        }
        elsif ( $dom_content->at('letsmt') ) {
            $content = $dom_content->at('body')->all_text(0);
        }
        else {
            $content = $dom_content->all_text(0);
        }

    }
    else {
        $content = 'No content found!';
    }

    # Take away double empty lines
    $content =~ s/\n[\s\n]*\n+/\n\n/sg;

    # Add line numbers, doesn't work properly with taking away empty lines and
    # all_text(0) that returns only content of tags but the tags itself can take
    # up several lines themselfes
    #    my $line_numbered_content;
    #    my $line = $from;
    #    while($content =~ /([^\n]+)\n?/g){
    #        $line_numbered_content .= "$line: $1\n";
    #        $line++;
    #    }
    $self->render( content => $content );
}

###############################################################################
# Ajax cat action raw
###############################################################################
sub ajax_cat_content_raw {
    my $self   = shift;
    my $slot   = $self->stash('slot');
    my $branch = $self->stash('branch');
    my $path   = $self->stash('path');
    my $user   = $self->session('user') || $self->config->{'system_user'};
    my $from   = $self->param('from') || 0;
    my $to     = $self->param('to') || 30;
    my $rev    = $self->param('rev') || 'HEAD';

    my $content =
      WebInterface::Model::Storage->cat( $self->stash('slot'),
        $self->stash('branch'),
        $self->stash('path'), $user, $from, $to, );

    $self->logger->debug( 'slot: ' . $slot );
    $self->logger->debug( 'branch: ' . $branch );
    $self->logger->debug( 'path: ' . $path );
    $self->logger->debug(
        'url_for(cat_content_raw): ' . $self->url_for('cat_content_raw') );

    $self->stash(
        from        => $from,
        to          => $to,
        reload_link => $self->url_for('cat_content_raw'),
        rev         => $rev,
    );

    unless ($content) {
        $content = 'No content found!';
    }

    $self->render( content => decode_entities($content) );
}

###############################################################################
# Add corpus action
###############################################################################
sub add_corpus {
    my $self = shift;

    my $slot_name   = $self->param('slot_name') || '';
    my $domain      = $self->param('domain');
    my $description = $self->param('description');
    my $provider    = $self->param('provider');
    my $group       = $self->param('group');

    my $user = $self->session('user');

    my @domains = (
        "Law",
        "Finance",
        "Business",
        "Information technology and data processing",
        "Electronics",
        "Industrial manufacturing",
        "Biotechnology and health",
        "Environment",
        "Energy",
        "Transport",
        "Communications systems",
        "Tourism",
        "Education",
        "National and international organizations and affairs",
        "Other",
    );

    $self->stash( domain => \@domains );

    unless ($slot_name) {
        return;
    }

    my $resource = new LetsMT::Resource( slot => $slot_name, user => $user );

    my $result = LetsMT::WebService::put(
        $resource->path_down,
        uid => $user,
        gid => $group eq 'public' ? 'public' : $user,
    );

    # write meta data to slot
    my $meta_result = WebInterface::Model::Meta->put(
        $slot_name,
        undef,    #branch
        undef,    #path
        $user,
        domain      => $domain,
        description => $description,
        provider    => $provider,
    );

    if ($result) {
        $self->flash(
            message_info => "Successfully created corpus '$slot_name'." );
        $self->redirect_to("/?open=$slot_name");
    }
    else {
        $self->stash( message_error => 'Error creating corpus!' );
    }
}

###############################################################################
# Upload action
###############################################################################
sub upload {
    my $self = shift;

    my $slot   = $self->stash('slot');
    my $branch = $self->stash('branch');

    my $comment   = $self->param('comment');
    my $lang      = $self->param('language');
    my $back_link = $self->param('back');

    my $user = $self->session('user');

    #$self->logger->debug( 'slot: '.  $slot );
    #$self->logger->debug( 'branch: '.$branch );

    # Prepare lists for language drop down
    my @lang = ( [ '-' => 'none' ] );
    my @langs = sort( all_language_names() );

    foreach my $lang (@langs) {
        my $code = language2code($lang);
        push( @lang, [ $lang . ' (' . $code . ')' => $code ] );
    }

    $self->stash(
        slot         => $slot,
        branch       => $branch,
        lang         => \@lang,
        file_formats => [qw/- tmx xml txt pdf doc xliff/],
        back_link    => $back_link || '',
    );

    #get the uploaded file
    my $upload = $self->req->upload('upload_file');

    if ($upload) {
        my $file_name_utf8 = $upload->filename;
        my $type           = undef;

        if ( $file_name_utf8 =~ /\.([^\.]+)(\.gz|\.tar|\.tgz|\.zip)?$/ ) {
            $type = $1;
        }

        unless ( LetsMT::Import::supported($type) ) {
            $self->stash( message_error => 'Cannot detect document type!' );
            return 0;
        }

        my ( $fh, $filename ) = tempfile();
        $upload->move_to($filename);

        my @path_elements = ( 'uploads', $type );
        push( @path_elements, $lang ) if ( $lang ne 'none' );
        push( @path_elements, $file_name_utf8 );

        #$self->logger->debug( 'path: '.  join('/', @path_elements) );

        my $resource = new LetsMT::Resource(
            slot => $slot,
            user => $branch,
            path => join( '/', @path_elements ),
        );

        my $result = LetsMT::WebService::put_file(
            $resource,
            $filename,
            uid    => $user,
            action => 'import',
        );

        if ($result) {
            $self->flash( message_info => 'Upload done.' );
            $self->redirect_to("/show/$slot/$branch");
        }
        else {
            $self->stash( message_error => 'Something went wrong!' );
        }
    }
    else {
        $self->render();
    }

}

###############################################################################
# Delete action
###############################################################################
sub delete {
    my $self = shift;

    ### Get path elements
    my $slot   = $self->stash('slot');
    my $branch = $self->stash('branch');
    my $path   = $self->stash('path');

    my $delete_result =
      WebInterface::Model::Storage->delete( $slot, $branch, $path,
        $self->session('user'),
      );

    if ($delete_result) {
        my $delete_path =
          join( '/', $slot, $path );    #branch should not be shown here
        $self->flash( message_info => "Resource '$delete_path' deleted. " );
    }
    else {
        $self->flash( message_error => 'Could not delete! ' );
    }

    if($path){
	$self->redirect_to('show');
    }
    else{ 
	$self->redirect_to('welcome');
    }
    return;
}

###############################################################################
# import action
###############################################################################
sub import {
    my $self = shift;

    ### Get path elements
    my $slot   = $self->stash('slot');
    my $branch = $self->stash('branch');
    my $path   = $self->stash('path');


    print "...$slot..$branch..$path...";

    return unless ($path=~/^uploads\//);

    my $resource = LetsMT::Resource::make( $slot, $branch, $path );
    &LetsMT::WebService::put_job( $resource, 
				  uid => $self->session('user'),
				  run => 'import' );

    $self->flash( message_info => "Resources in '$resource' will be (re-)imported." );
#    $self->render;
    $self->redirect_to("show/$slot/$branch/$path");
    return;
}

###############################################################################
# realign action
###############################################################################
sub realign {
    my $self = shift;

    ### Get path elements
    my $slot   = $self->stash('slot');
    my $branch = $self->stash('branch');
    my $path   = $self->stash('path');

    return unless ($path=~/^xml\//);

    my $resource = LetsMT::Resource::make( $slot, $branch, $path );
    &LetsMT::Webservice::put_job( $resource, 
				  uid => $self->session('user'),
				  run => 'realign' );

    $self->flash( message_info => "Parallel resources in '$resource' will be re-aligned." );
    return;
}

###############################################################################
# Helper function: aligned view
###############################################################################
sub _aligned_view {
    my ( $self, $fromDoc, $toDoc, $content, $from, $to ) = @_;

    #-------------------------------------------
    # guess the amount of src and trg data we need to read:
    #   - parse the sentence alignment
    #   - look for the first and the last linked sentence IDs in src and trg
    #   - assume that there will be not more than 2 lines per sentence in XML
    #     (including surrounding tags like <p> ...)

    my $dom_align  = Mojo::DOM->new($content);
    my $links      = $dom_align->find('link');
    my $reverse    = $links->reverse();
    my $first_link = $links->first;
    my $last_link  = $reverse->first;

    my ( @idSrc, @idTrg );

    foreach ( $first_link, $last_link ) {
        my ( $from_target, $to_target ) = split( ';', $_->{'xtargets'} );
        my @from_target_parts = split( ' ', $from_target );
        my @to_target_parts   = split( ' ', $to_target );

        ## TODO: links can be empty on src or target side!
        push( @idSrc, $from_target_parts[0] );
        push( @idTrg, $to_target_parts[0] );
    }
    $idSrc[0] = $from unless ( $idSrc[0] );
    $idTrg[0] = $from unless ( $idTrg[0] );
    $idSrc[1] = $to   unless ( $idSrc[1] );
    $idTrg[1] = $to   unless ( $idTrg[1] );

    #-------------------------------------------

    #    $self->logger->debug( "$idSrc[0] ... $idSrc[1]" );
    #    $self->logger->debug( "$idTrg[0] ... $idTrg[1]" );

    my $user  = $self->session('user') || $self->config->{'system_user'};
    my $host  = $self->req->url->clone->base->to_string;
    my $parts = ( Mojo::Path->new( $self->req->url->clone ) )->parts;

    shift @$parts;    #sift off action
    my $slot   = shift @$parts;
    my $branch = shift @$parts;

    ### create arrays based on IDs with sentences
    # fromDoc
    my $from_file =
      WebInterface::Model::Storage->cat( $slot, $branch, 'xml/' . $fromDoc,
        $user, $idSrc[0], 2 * $idSrc[1] + 10 );
    my $dom_from = Mojo::DOM->new( decode_entities($from_file) );

# $self->logger->debug( 'content from:'.decode_entities($from_file) );
# $self->logger->debug( 'dom_from size: ' . total_size($dom_from)/1000000 . 'MB' );

    # toDoc
    my $to_file =
      WebInterface::Model::Storage->cat( $slot, $branch, 'xml/' . $toDoc,
        $user, $idTrg[0], 2 * $idTrg[1] + 10 );

    my $dom_to = Mojo::DOM->new( decode_entities($to_file) );

 # $self->logger->debug( 'content to:'.decode_entities($to_file) );
 # $self->logger->debug( 'dom_to size: ' . total_size($dom_to)/1000000 . 'MB' );

    # alignment doc
    my $result_array;
    my $index = 0;
    $links->each(
        sub {
            my ( $from_target, $to_target ) = split( ';', $_->{'xtargets'} );
            my @from_target_parts = split( ' ', $from_target );
            my @to_target_parts   = split( ' ', $to_target );

            # $self->logger->debug( 'from ' . join( ',', @from_target_parts ) );
            # $self->logger->debug( 'to ' . join( ',',   @to_target_parts ) );

            my $from_target_content;
            foreach my $target (@from_target_parts) {
                if ( my $tag = $dom_from->at( 's[id =' . $target . ']' ) ) {
                    $from_target_content .= $tag->text . ' ';
                }
            }

            my $to_target_content;
            foreach my $target (@to_target_parts) {
                if ( my $tag = $dom_to->at( 's[id =' . $target . ']' ) ) {
                    $to_target_content .= $tag->text . ' ';
                }
            }

            @$result_array[ $index++ ] = {
                from_links   => join( ' ', @from_target_parts ),
                to_links     => join( ' ', @to_target_parts ),
                from_content => $from_target_content,
                to_content   => $to_target_content,
            };
        }
    );

#$self->logger->debug( 'result_array size: ' . total_size($result_array)/1000000 . 'MB' );

    return $result_array;
}

###############################################################################
# Helper function: Get a listing of the resource to get the revision history
# Returns an array ref of hashes with keys {title, value, selected}
###############################################################################
sub _get_revision_array {
    my ( $self, $path, $rev ) = @_;

    my $listing =
      WebInterface::Model::Storage->get_from_path( $path,
        $self->session('user'), $rev, );

    my @rev_array;
    my $selection_set = 0;
    my $dom_listing   = Mojo::DOM->new($listing);
    $dom_listing->find('history')->each(
        sub {
            my $sel_string;
            if ( $_->{'revision'} eq $rev ) {
                $sel_string    = 'selected="selected"';
                $selection_set = 1;

            }
            else {
                $sel_string = '';
            }
            push @rev_array,
              {
                title    => $_->{'revision'} . ': ' . $_->text(),
                value    => $_->{'revision'},
                selected => $sel_string,
              };
        }
    );

# If $rev = 'HEAD' and didn't match any revision number -> select last revistion
    if ( !$selection_set && @rev_array ) {
        $rev_array[-1]{selected} = 'selected="selected"';
    }

    # make sure the last revision is called head so it can be filered out later
    # since the metadata API doesn't take a revision number for the latest rev
    if (@rev_array) { $rev_array[-1]{value} = 'HEAD'; }

    return \@rev_array;
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
