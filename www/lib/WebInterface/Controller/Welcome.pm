package WebInterface::Controller::Welcome;
use Mojo::Base 'Mojolicious::Controller';

use open qw(:std :utf8);
use LetsMT::WebService;
use WebInterface::Model::Meta;

sub index {
    my $self = shift;
    my $user = $self->session('user') || $self->config->{'system_user'};

    my $slot_to_open = $self->param('open') || 'none';

    $self->logger->debug('index');

    # Search for branches, either as the user if logged in or as system_user
    my $meta_result = WebInterface::Model::Meta->search(
        'uid'           => $user,
        'resource-type' => 'branch',
        'action'        => 'list_all',
    );

    # parse into dom and store needed information in @branches
    my $dom = Mojo::DOM->new($meta_result);

    if (  !$dom->find('status')->size
        || $dom->at('status[type]')->attr('type') eq 'error' )
    {
        $self->flash( message_error => 'Hopsan! Database error!' );
        $self->redirect_to('/error');
        return;
    }

    my $branches;
    my $entries = $dom->find('entry');

    unless ( $entries->size ) {
        $self->stash( message_info => 'Hopsan! No entries found in database!' );
        my @tmp;
        $self->stash( branches => \@tmp );
        return;
    }

    for my $result ( $entries->each ) {
        my ( $slot, $branch ) = split( '/', $result->{'path'} );

        #$self->logger->debug( 'branches: '.$result->{'path'} );

        my $owner =
          defined( $result->at('owner') ) ? $result->at('owner')->text : 'none';
        my $other_owner_hint =
          ( $owner ne $user && $user ne $self->system_user )
          ? " (owned by $owner)"
          : '';

        my $permissions;
        if ( defined( $result->at('gid') ) ) {
            if ( $result->at('gid')->text eq $user ) {
                $permissions = 'private';
            }
            else {
                $permissions = $result->at('gid')->text;
            }
        }
        else {
            $permissions = 'none';
        }

        my $sentence_count_corpus = '-';

        #       WebInterface::Model::Meta->count_sentences_of_slot(
        #                    $slot,
        #                    $branch,
        #                    $user,
        #                    'corpusfile',
        #                );

        my $sentence_count_sent = '-';

        #        WebInterface::Model::Meta->count_sentences_of_slot(
        #                    $slot,
        #                    $branch,
        #                    $user,
        #                    'sentalign',
        #                );

        push(
            @$branches,
            {
                'path'     => $result->{'path'},
                'name'     => $slot . $other_owner_hint,
                'owner'    => $owner,
                'provider' => defined( $result->at('provider') )
                ? $result->at('provider')->text
                : 'none',
                'group'  => $permissions,
                'create' => defined( $result->at('create') )
                ? $result->at('create')->text
                : 'none',
                'description' => defined( $result->at('description') )
                ? $result->at('description')->text
                : 'none',
                'langs' => defined( $result->at('langs') )
                ? $result->at('langs')->text
                : 'none',
                'parallel-langs' => defined( $result->at('parallel-langs') )
                ? $result->at('parallel-langs')->text
                : 'none',
                'domain' => defined( $result->at('domain') )
                ? $result->at('domain')->text
                : 'none',
                'slot'         => $slot,
                'branch'       => $branch,
                'count_corpus' => $sentence_count_corpus,
                'count_sent'   => $sentence_count_sent,
            },
        );
    }

    my @sorted_branches =
      sort { lc( $a->{name} ) cmp lc( $b->{name} ) } @$branches;

    $self->stash(
        slot_to_open => $slot_to_open,
        branches     => \@sorted_branches,
    );

    $self->render('welcome/index');
}

###############################################################################
# Get details for a slot
###############################################################################
sub get_details {
    my $self = shift;

    my $slot   = $self->stash('slot');
    my $branch = $self->stash('branch');

    my $user = $self->session('user') || $self->config->{'system_user'};

    $self->logger->debug( 'get_details called for ' . $slot . '/' . $branch );

    # Get meta data for the requested branch
    my $meta_result =
      WebInterface::Model::Meta->get( $slot, $branch, undef, $user, );
    $self->logger->debug(
        'get_details for ' . $slot . '/' . $branch . ': ' . $meta_result );

    my $entry = Mojo::DOM->new($meta_result);

    $self->logger->debug( 'entry: ' . $entry->all_text );

#    unless ( $entry->find('entry') ) { return 'Could not find any details...';}

    my $rc_path =
      defined( $entry->at('entry')->attrs('path') )
      ? $entry->at('entry')->attrs('path')
      : 'none';
    $self->logger->debug( 'rc_path: ' . $rc_path );

    my $provider =
      defined( $entry->at('provider') ) ? $entry->at('provider')->text : 'none';
    $self->logger->debug( 'provider: ' . $provider );

    my $langs =
      defined( $entry->at('langs') ) ? $entry->at('langs')->text : 'none';
    $self->logger->debug( 'langs: ' . $langs );

    my $parallel =
      defined( $entry->at('parallel-langs') )
      ? $entry->at('parallel-langs')->text
      : 'none';
    $self->logger->debug( 'parallel: ' . $parallel );

    my $create =
      defined( $entry->at('create') ) ? $entry->at('create')->text : 'none';
    $self->logger->debug( 'create: ' . $create );

    my $owner =
      defined( $entry->at('owner') ) ? $entry->at('owner')->text : 'none';
    $self->logger->debug( 'owner: ' . $owner );

    my $uid = defined( $entry->at('uid') ) ? $entry->at('uid')->text : 'none';
    $self->logger->debug( 'uid: ' . $uid );

    $self->logger->debug( 'rc_path: ' . $rc_path );

    my $sOut =
      '<table cellpadding="5" cellspacing="0" border="0" style="width:100%;">';
    $sOut .= '   <tr>';
    $sOut .= '      <td id="details">';
    $sOut .= '         <div>';
    $sOut .= '            <span class="gray">Provider:</span>';
    $sOut .= '            <span>' . $provider . '</span>';
    $sOut .= '         </div>';
    $sOut .= '         <div>';
    $sOut .= '            <span class="gray">Languages:</span>';
    $sOut .= '            <span>' . $langs . '</span>';
    $sOut .= '         </div>';
    $sOut .= '         <div>';
    $sOut .= '            <span class="gray">Language Pairs:</span>';
    $sOut .= '            <span>' . $parallel . '</span>';
    $sOut .= '         </div>';
    $sOut .= '         <div>';
    $sOut .= '            <span class="gray">Create Date:</span>';
    $sOut .= '            <span>' . $create . '</span>';
    $sOut .= '         </div>';
    $sOut .= '         <div>';
    $sOut .= '            <span class="gray">Owner:</span>';
    $sOut .= '            <span>' . $owner . '</span>';
    $sOut .= '         </div>';
    $sOut .= '      </td>';
    $sOut .= '      <td id="details" colspan="3">';
    $sOut .= '         ' . _get_matrix( $slot, $branch, $user );
    $sOut .= '      </td>';
    $sOut .= '      <td id="details" colspan="2">';
    $sOut .= '         <div class="button_menu action_menu">';
    $sOut .= '            <ul>';
    $sOut .=
        '               <li><a href="'
      . $self->url_for("/show") . '/'
      . $rc_path
      . '" title="browse corpus" id="icon_link" class="ui-state-default ui-corner-all action_buttons"><span class="ui-icon ui-icon-search"></span>browse</a></li>';

    if ( $self->session('user') ) {
        if ( $owner eq $user ) {
            $sOut .=
                '<li><a href="'
              . $self->url_for("/upload") . '/'
              . $rc_path
              . '" title="upload data" id="icon_link" class="ui-state-default ui-corner-all action_buttons"><span class="ui-icon ui-icon-plus"></span>upload</a></li>';
            $sOut .=
                '<li><a href="'
              . $self->url_for("/edit") . '/'
              . $rc_path
              . '" title="edit corpus" id="icon_link" class="ui-state-default ui-corner-all action_buttons"><span class="ui-icon ui-icon-pencil"></span>edit</a></li>';
            $sOut .= '<li><a href="#" title="delete corpus" id="icon_link" class="ui-state-default ui-corner-all action_buttons" onclick="delete_corpus( \''
              . $self->url_for("delete")
              . '\')" ><span class="ui-icon ui-icon-trash"></span>delete</a></li>';
        }
        else {
            $sOut .=
                '<li><a href="'
              . $self->url_for("/clone/") . '/'
              . $rc_path
              . '" title="clone corpus" id="icon_link" class="ui-state-default ui-corner-all action_buttons"><span class="ui-icon ui-icon-copy"></span>clone</a></li>';
        }
    }
    $sOut .= '             </ul>';
    $sOut .= '          </div>';
    $sOut .= '       </td>';
    $sOut .= '    </tr>';
    $sOut .= '</table>';

    $self->logger->debug( 'sOut: ' . $sOut );

    $self->render( data => $sOut, format => 'html' );
}

# Get matrix (table) of language pairs
sub _get_matrix {
    my $slot   = shift;
    my $branch = shift;
    my $user   = shift;

    return WebInterface::Model::Meta->get_lang_matrix( $slot, $branch, $user, );

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
