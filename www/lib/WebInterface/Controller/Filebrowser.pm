#-*-perl-*-
package WebInterface::Controller::Filebrowser;

use strict;

use open qw(:std :utf8);

use HTML::Entities ();
use Switch;
use File::Spec;

use Mojo::Base 'Mojolicious::Controller';

use WebInterface::Model::Storage;
use WebInterface::Model::Meta;

# define file extentions and dirs that should be hidden in the file browser
my @hidden_files_extentions = qw/err import_job import_job_err_\d /;
my @hidden_dirs             = qw/uploads/;

# max number of entries to check import status in file browser
my $show_status_max = 20;
my $show_max_entries = 200;


sub list {
    my $self = shift;

    my $slot    = $self->stash('slot');
    my $branch  = $self->stash('branch');
    my $rc_path = $self->stash('path');

    my $dir      = $self->param('dir');
    my $download = $self->param('download');
    my $user     = $self->session('user') || 'mojo';

    my $list_result =
      WebInterface::Model::Storage->get_from_path( $dir, $user, );

    #we want only the file part to load the tabs on the right side with
    #information about the requested file
    ( my $volume, my $path, my $file ) = File::Spec->splitpath($rc_path);

    my $dom = Mojo::DOM->new($list_result);

    my ($thisSlot, $thisBranch, $thisDir ) = split(/\/+/,$dir);
    my $reimport = $thisDir eq 'uploads' ? 1 : 0;

    my $entries = '<ul class="jqueryFileTree" style="display:none;">';

    if ( $dom->at('entry') ) {
	my $nr_entries = $dom->find('entry')->size;
	my $count = 0;

        for my $entry ( sort $dom->find('entry')->each ) {

	    last if ($count > $show_max_entries);
	    my $shown = 0;

            if ( $entry->{'kind'} eq 'file' ) {
                my @filename_parts = split( /\./, $entry->name->text );

                my $ext = @filename_parts ? pop @filename_parts : '';

                # skip files with certain extentions, like .err
                unless ( $ext =~
			 /^err$|^import_job$|^import_job_err_*|^import_job_out_*/ ) {

		    $shown = 1;
                    #If the requested file name matches the current entry
                    #we add some js that loads the tabs
                    if ( $file eq $entry->name->text ) {
                        $entries .=
                            '<script type="text/javascript">'
                          . '       load_tabs("'
                          . $slot . '/'
                          . $branch . '/'
                          . $rc_path . '");'
                          . '</script>';
                    }
		    # don't check the import status if there are too many files
		    my $import_status = 
			$nr_entries > $show_status_max ? "" 
			 : get_import_status( $dir . $entry->name->text, $user );
                    $entries .=
                        '<li class="file ext_' 
                      . $ext . '">'
                      . '<a href="#" rel="'
                      . $dir
                      . $entry->name->text
                      . '" title="'
                      . $entry->name->text . '">'
                      . '<span class="file_icon">&nbsp;</span>'
                      . '<span class="file_name">'
                      . $entry->name->text
                      . '</span>'
                      . '<span class="file_property">'
                      . $import_status
                      . '</span>'
                      . '<span class="file_property">'
                      . get_filesize_str( $entry->size->text )
                      . '</span>' . '</a>';
		}
            }
            elsif ( $entry->{'kind'} eq 'dir' ) {
                unless ( grep { $_ eq $entry->name->text } @hidden_dirs ) {

		    $shown = 1;
                    $entries .=
                        '<li class="directory collapsed">'
                      . '<a href="#" rel="'
                      . $dir . '/'
                      . $entry->name->text . '/'
                      . '" title="'
                      . $entry->name->text . '">'
                      . '<span class="file_icon">&nbsp;</span>'
                      . '<span class="file_name">'
                      . $entry->name->text
                      . '</span>' . '</a>';
		}
	    }
	    if ($shown){
		$count++;
		if ( $self->session('user') ) {
		    $entries .=
			'<span class="file_property ui-icon ui-icon-trash link_cursor" title="delete resource" onclick="delete_file(\''
			. $dir
			. $entry->name->text
			. '\')">&nbsp:</span>';
		    if ( $download ){
			$entries .=
			    '<span class="file_property ui-icon ui-icon-arrowthickstop-1-s link_cursor" title="download resource" onclick="download_file(\''
			    . $dir
			    . $entry->name->text
			    . '\')">&nbsp;</span>';
		    }
		    elsif ( $reimport ) {
			$entries .=
			    '<span class="file_property ui-icon ui-icon-arrowthickstop-1-w link_cursor" 
                                       title="import resource" onclick="import_resource(\''
				       . $dir
				       . $entry->name->text
				       . '\')">&nbsp;</span>';
		    }
		}
		$entries .= '</li>';
	    }
        }
    }
    else {
        $entries .= '<li>No entries found!</li>';
    }
    $entries .= '</ul>';

    $self->render( data => $entries );
}

sub get_filesize_str {
    my $size = shift;

    if ( $size > 1099511627776 )    #   TB: 1024 GiB
    {
        return sprintf( "%.2f TB", $size / 1099511627776 );
    }
    elsif ( $size > 1073741824 )    #   GiB: 1024 MiB
    {
        return sprintf( "%.2f GB", $size / 1073741824 );
    }
    elsif ( $size > 1048576 )       #   MiB: 1024 KiB
    {
        return sprintf( "%.2f MB", $size / 1048576 );
    }
    elsif ( $size > 1024 )          #   KiB: 1024 B
    {
        return sprintf( "%.2f KB", $size / 1024 );
    }
    else                            #   bytes
    {
        return sprintf( "%.0f bytes", $size );
    }
}

sub get_import_status {
    my $path = shift;
    my $user = shift;

    my $status_string = WebInterface::Model::Meta::import_status( $path, $user );

    switch ($status_string) {
        case 'waiting in import queue' {
            return "";
        }

        case 'importing' {
            return
              "<img src='/images/yellow_dot.png' title='status: importing'/>";
        }

        case 'imported' {
            return
              "<img src='/images/green_dot.png' title='status: imported'/>";
        }

        case 'updated' {
            return "<img src='/images/blue_dot.png' title='status: updated'/>";
        }

        case 'empty resource (imported nothing)' {
            return "<img src='/images/red_dot.png' title='status: imported nothing'/>";
        }

        else {
            return "<img src='/images/gray_dot.png' title='status: unknown'/>";
        }
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
