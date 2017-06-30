package WebInterface::Controller::Metadata;

use warnings;
use strict;

use open qw(:std :utf8);

use XML::Simple;
use Data::Dumper;

use Mojo::Base 'Mojolicious::Controller';

use WebInterface::Model::Meta;

use LetsMT::WebService;
use LetsMT::Resource;

###############################################################################
# Show action - displays metadata of a resource
###############################################################################
sub ajax_show {
    my $self = shift;

    my $slot   = $self->stash('slot');
    my $branch = $self->stash('branch');
    my $path   = $self->stash('path');
    my $rev    = $self->param('rev') || 'HEAD';

    my $user = $self->session('user') || $self->system_user;

    my $entries =
      WebInterface::Model::Meta->get_meta_list( $slot, $branch, $path, $user,
        $rev, );

    my @content;
    foreach my $key ( keys %$entries ) {

        my $value = ref $entries->{$key} ? 'none' : $entries->{$key};

        # for these types of files we want to link the entries
        if (   $key eq 'imported_from'
            || $key eq 'source-document'
            || $key eq 'target-document'
            || $key eq 'imported_to'
        ) {
            my @files = split( ',', $value );
            my @values;
            foreach my $file (@files) {
                my $link = "$slot/$branch/$file";
                push( @values,
                        "<a href='#' onclick=load_tabs('" 
                      . $link . "') >" 
                      . $file
                      . "</a>" );
            }
            $value = join( ', ', @values );
        }

        push( @content, { key => $key, value => $value } );
    }

    my @sorted = sort { $a->{'key'} cmp $b->{'key'} } @content;

    $self->render( content => \@sorted );
}

###############################################################################
# Show import status
###############################################################################
sub ajax_show_import_status {
    my $self = shift;

    my $slot   = $self->stash('slot');
    my $branch = $self->stash('branch');
    my $path   = $self->stash('path');

    my $user = $self->session('user') || 'mojo';

    my $meta = WebInterface::Model::Meta->get( $slot, $branch, $path, $user, );

    my $dom = XMLin($meta);

    my $status = $dom->{'list'}->{'entry'}->{'status'};

    $self->render( data => $status );
}

###############################################################################
# Ajax return language count
###############################################################################

sub language_count {
    my $self = shift;
    my $count;

    my $slot   = $self->stash('slot');
    my $branch = $self->stash('branch');
    my $path   = $self->stash('path');

    my $type = $self->param('type');
    my $language = $self->param('language') || '';

    my $user = $self->session('user') || 'mojo';

    my $sentence_count =
      WebInterface::Model::Meta->count_sentences_of_slot( $slot, $branch, $user,
        $type, $language, );

    $count = defined $sentence_count ? $sentence_count : 0;
    my $pretty = pretty_number($count);

    if ( $language ) {
        $pretty =
            "<a href='"
          . $self->url_for('download')
          . "' title='download $language'>".$pretty."</a>";
    }

    $self->render( data => $pretty );
}


sub pretty_number{
    my $nr=shift;
    my $dec = shift || 1;

    if ($nr>1000000000){
        return sprintf "%.${dec}fG",$nr/1000000000;
    }
    if ($nr>100000){
        return sprintf "%.${dec}fM",$nr/1000000;
    }
    if ($nr>100){
        return sprintf "%.${dec}fk",$nr/1000;
    }
    return $nr;
}

sub thousands{
    my $nr=shift;
    $nr =~ s/(\d)(?=(\d{3})+(\D|$))/$1\,/g;
    return $nr;
}



###############################################################################
# Edit metadata
###############################################################################
sub edit {
    my $self = shift;

    my $slot    = $self->stash('slot');
    my $branch  = $self->stash('branch');
    my $rr_path = $self->stash('rr_path');

    my $back_link = $self->param('back');

    my $user = $self->session('user') || 'mojo';

    #    $self->logger->debug('slot: '.$slot);
    #    $self->logger->debug('brnach: '.$branch);
    #    $self->logger->debug('rr_path: '.$rr_path);
    #    $self->logger->debug('user: '.$user);

    #$self->logger->debug( 'update:'.$self->param('update') );

    # If the form was submitted -> update meta database
    if ( $self->param('update') ) {

        # rewrite permission/gid to $user if undef or 'private'
        my $permission;
        if (  !$self->param('permission')
            || $self->param('permission') eq 'private' )
        {
            $permission = $user;
        }
        else {
            $permission = $self->param('permission');
        }

        my $meta_slots = {
            domain      => $self->param('domain')      || 'Other',
            description => $self->param('description') || '',
            provider    => $self->param('provider')    || '',
            gid         => $permission,
        };

        # Check for Import- and AlignParameter fields from the form and add them
        # to $uploads_meta
        my $meta_uploads;
        foreach my $param ( $self->param ) {
            $self->logger->debug( 'param: ' . $param );
            if ( $param =~ m/^(ImportPara_|AlignPara_)/ ) {
                $self->logger->debug('match');
                $meta_uploads->{$param} = $self->param($param);
            }
        }

        # Write new or updated metadata to 'slot/branch/path'
        my $result_slot =
          WebInterface::Model::Meta->post( $slot, $branch, $rr_path, $user,
            %$meta_slots, );

        # Write new or updated metadata to 'uploads'
        my $result_uploads =
          WebInterface::Model::Meta->post( $slot, $branch, 'uploads', $user,
            %$meta_uploads, );

        # Check if metadata update wokred and set error or ok message
        if ( $result_slot && $result_uploads ) {
            $self->flash( message_info => 'Meta Data updated!' );
            $self->redirect_to('welcome');
            return;
        }
        else {
            $self->stash( message_error => 'Meta Data updated failed!' );
        }

    }

    # If page was loaded without form submission -> load current meta values
    # from DB on slot level and from uploads dir
    my $meta_slot = WebInterface::Model::Meta->get( $slot, $branch, $rr_path, $user, );
    my $dom_slot = XMLin( $meta_slot, SuppressEmpty => undef );

    my $domain   = $dom_slot->{'list'}->{'entry'}->{'domain'}   || 'Other';
    my $provider = $dom_slot->{'list'}->{'entry'}->{'provider'} || '';
    my $description = $dom_slot->{'list'}->{'entry'}->{'description'} || '';
    my $gid         = $dom_slot->{'list'}->{'entry'}->{'gid'}         || $user;

  # For the import/align parameter we need to check the uploads dir for metadata
    my $meta_uploads = WebInterface::Model::Meta->get( $slot, $branch, 'uploads', $user, );
    my $dom_uploads = XMLin( $meta_uploads, SuppressEmpty => undef );

    # Check for each input field from the config if a matching entry was found
    # in the meta data and write it to an array to pre-select the form fields
    my %form_fields;
    foreach my $field ( keys %{ $self->config->{forms}->{edit_meta} } ) {
        my $meta_key =
          $self->config->{forms}->{edit_meta}->{$field}->{meta_key};
        $form_fields{$meta_key} = $dom_uploads->{'list'}->{'entry'}->{$meta_key}
          || $self->config->{forms}->{edit_meta}->{$field}->{default};
    }

    # Load the list of domains from config
    my $domains = $self->config->{domains};

    # Put the domain list in a hash for the pull down menue
    my @domain_list;
    foreach my $domain_name (@$domains) {
        push @domain_list,
          {
            name     => $domain_name,
            selected => $domain_name eq $domain ? 1 : 0,
          };
    }

    # get groups for user and put them in a hash for the pull down menue
    my $user_groups = WebInterface::Model::Meta->get_groups($user);
    my @other_groups;
    foreach (@$user_groups) {

        # mojo group should not be visible, public and private ($user) is in
        # std_groups list instead
        unless ( $_ =~ m/mojo|public|$user/ ) {
            push @other_groups,
              {
                name     => $_,
                selected => $_ eq $gid ? 1 : 0,
              };
        }
    }

    # add standard groups public and private
    my @std_groups = (
        { name => 'public',  selected => 'public' eq $gid ? 1 : 0 },
        { name => 'private', selected => $user    eq $gid ? 1 : 0 },
    );

    $self->stash(
        domain_list  => \@domain_list,
        form_fields  => \%form_fields,
        slot         => $slot,
        path         => join( '/', $slot, $branch, $rr_path ),
        std_groups   => \@std_groups,
        other_groups => \@other_groups,
        domain       => $domain,
        provider     => $provider,
        description  => $description,
        back_link => $back_link || '',
    );
}

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
1;
