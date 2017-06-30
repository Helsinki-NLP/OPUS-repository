package WebInterface::Model::Meta;
use strict;
use warnings;
use v5.10;

use open qw(:std :utf8);

use Data::Dumper;
use Encode qw/is_utf8 decode encode/;
use HTML::Entities;
use XML::Simple;

use base qw/Mojo::Base/;

use LetsMT::WebService;
use LetsMT::Resource;

###############################################################################
# Get
###############################################################################
sub get {
    my ( $self, $slot, $branch, $path, $user ) = @_;

    my $resource = LetsMT::Resource::make( $slot, $branch, $path );

    my $result = LetsMT::WebService::get_meta(
        $resource,
        uid    => $user,
        action => 'list_all',
    );

    return $result;
}

###############################################################################
# Get from path
###############################################################################
sub get_from_path {
    my ( $path, $user ) = @_;

    my $resource = LetsMT::Resource::make_from_path($path);

    my $result = LetsMT::WebService::get_meta(
        $resource,
        uid    => $user,
        action => 'list_all',
    );

    return $result;
}

###############################################################################
# Put
###############################################################################
sub put {
    my ( $self, $slot, $branch, $path, $user, %meta ) = @_;

    my $resource = LetsMT::Resource::make( $slot, $user, $path, );

    foreach my $key ( keys %meta ) {
        $meta{$key} = encode_entities( $meta{$key} );
    }

    my $result = LetsMT::WebService::put_meta( $resource, %meta );

    return $result;
}

###############################################################################
# Post
###############################################################################
sub post {
    my ( $self, $slot, $branch, $path, $user, %meta ) = @_;

    my $resource = LetsMT::Resource::make( $slot, $user, $path, );

    foreach my $key ( keys %meta ) {
        $meta{$key} = encode_entities( $meta{$key} );
    }

    my $result = LetsMT::WebService::post_meta( $resource, %meta );

    return $result;
}

###############################################################################
# Search
###############################################################################
sub search {
    my ( $self, %meta ) = @_;

    my $http_response = LetsMT::WebService::search_meta(%meta);

    return $http_response;
}

###############################################################################
# Recursive Search
###############################################################################
sub search_recursive {
    my $resource = shift;
    my $user     = shift;
    my %meta     = @_;

    $meta{'uid'}  = $user;
    $meta{'type'} = 'recursive';

    return LetsMT::WebService::get_meta( $resource, %meta );

}

###############################################################################
# Delete
###############################################################################
sub delete {

}

###############################################################################
# Count the number of sentences in a slot
###############################################################################
sub count_sentences_of_slot {
    my ( $self, $slot, $branch, $user, $type, $languages ) = @_;
    my $ids_result;

    my $resource = LetsMT::Resource::make( $slot, $branch );

    if ($languages) {
        $ids_result = search_recursive(
            $resource,
            $user,
            'resource-type'   => $type,
            'ALL_OF_language' => $languages,
            action            => 'SUM_size',
        );
    }
    else {
        $ids_result = search_recursive(
            $resource,
            $user,
            'resource-type' => $type,
            action          => 'SUM_size'
        );
    }

    if ($ids_result) {
        my $dom = Mojo::DOM->new->charset('UTF-8')->xml(1)->parse($ids_result);
        my $id  = $dom->at('SUM_size');
        return $id ? $id->text : 0;
    }

    return 0;
}

###############################################################################
# Return the import status of a resource
###############################################################################
sub import_status {
    my ( $path, $user ) = @_;

    my $meta = get_from_path( $path, $user, );

    my $dom = XMLin($meta);

    my $status = $dom->{'list'}->{'entry'}->{'status'};

    return $status;
}

###############################################################################
# Get matrix of language pairs
###############################################################################
sub get_lang_matrix {
    my ( $self, $slot, $branch, $user ) = @_;

    my $resource = LetsMT::Resource::make( $slot, $branch );

    my $result = LetsMT::WebService::get_meta(
        $resource,
        uid    => $user,
        action => 'list_all',
    );

    #$self->logger->debug( 'matrix search: '.$result );

    my $dom = XMLin($result);

    my $langs_string = $dom->{'list'}->{'entry'}->{'langs'};

    #my $owner        = $dom->{'list'}->{'entry'}->{'owner'};

    return '' unless ( $langs_string && !ref $langs_string );

    # split and sort languages
    my @langs = split( ',', $langs_string );
    @langs = sort(@langs);

    my $matrix = "<table class='matrix_table'>\n";

    # add colgroups for heighlighting columns by javascript
    for ( my $i = 0 ; $i <= scalar @langs ; $i++ ) {
        $matrix .= "<colgroup></colgroup>\n";
    }

    $matrix .= "<tr>\n";
    $matrix .= "<td class='matrix_header'></td>\n";

    # add the target language header row
    foreach my $lang_target (@langs) {
        $matrix .= "<td class='matrix_header'>" . $lang_target . "</td>\n";
    }
    $matrix .= "</tr>\n";
    my $done;
    my $id;
    my $path;
    my $type;
    my $language;
    foreach my $lang_source (@langs) {

        # add the source language header column
        $matrix .= "<tr><td class='matrix_header'>" . $lang_source . "</td>\n";
        foreach my $lang_target (@langs) {
            my $cell_content;
            my $lang_dir = _sort_lang_pair( $lang_source, $lang_target );
            unless ( $lang_source eq $lang_target
                || $done->{$lang_target}
                && $done->{$lang_target} =~ m/$lang_source/ )
            {
                $done->{$lang_source} .= ' ' . $lang_target;
                $id           = "lang_matrix_field_$lang_source-$lang_target";
                $type         = 'sentalign';
                $language     = $lang_source . ',' . $lang_target;
                $path         = "xml/$lang_dir";
                $cell_content = '-'
                  ; #"<a href='/download/$slot/$branch/xml/$lang_dir' title='download $lang_dir'>-</a>";
            }
            elsif ( $lang_source eq $lang_target ) {
                $id           = "lang_matrix_field_$lang_source-$lang_target";
                $type         = 'corpusfile';
                $language     = $lang_source;
                $path         = "xml/$lang_source";
                $cell_content = '-'
                  ; #"<a href='/download/$slot/$branch/xml/$lang_source' title='download $lang_source'>-</a>";
            }
            else {
                $id           = "lang_matrix_field_$lang_source-$lang_target";
                $type         = 'view';
                $language     = $lang_source . ',' . $lang_target;
                $path         = "xml/$lang_dir/dummy.file";
                $cell_content = '-'
                  ; #"<a href='<%= url_for('show')/$slot/$branch/xml/$lang_dir/dummy.file' title='browse $lang_dir'>view</a>";
            }
            $matrix .= "<td 
                            id='$id' 
                            slot='$slot' 
                            branch='$branch'    
                            path='$path' 
                            type='$type'
                            language='$language' 
                        >";
            $matrix .= $cell_content;
            $matrix .= "</td>\n";
        }
        $matrix .= "</tr>\n";
    }
    $matrix .= "</table>\n";

    return $matrix;
}

###############################################################################
# Get a hash containing the metadata entries for a resource at a revision
###############################################################################
sub get_meta_list {
    my ( $self, $slot, $branch, $path, $user, $rev ) = @_;

    #For metadata the HEAD revision is returned with no revision given at all
    $path = $rev eq 'HEAD' ? $path : $path . '@' . $rev;

    my $meta = WebInterface::Model::Meta->get( $slot, $branch, $path, $user, );

    my $dom = XMLin($meta);

    return $dom->{'list'}->{'entry'};
}

###############################################################################
# Get groups of a user
###############################################################################
sub get_groups {
    my ( $self, $user ) = @_;

    my $result = LetsMT::WebService::get_group(
        undef,    #group
        undef,    #user
        $user,    #uid
    );

    my $dom = Mojo::DOM->new->charset('UTF-8')->xml(1)->parse($result);

    my @groups;
    for my $group ( $dom->find('entry')->each ) {
        push @groups, $group->{'id'};
    }

    @groups = sort @groups;

    return \@groups;
}

###############################################################################
# Helper function:
# Creates a string like 'en-de' with language IDs in alphabetical order
# or just a single language ID if no second one is present
###############################################################################
sub _sort_lang_pair {
    my ( $lang_1, $lang_2 ) = @_;

    if ( $lang_1 && $lang_2 ) {
        return $lang_1 lt $lang_2
          ? $lang_1 . '-' . $lang_2
          : $lang_2 . '-' . $lang_1;
    }
    elsif ($lang_1) {
        return $lang_1;
    }
    else {
        return '';
    }
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
