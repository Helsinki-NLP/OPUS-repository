package LetsMT;

=head1 NAME

LetsMT - Perl modules and tools for the LetsMT! project.

=head1 DESCRIPTION

LetsMT is a collection of Perl modules for the LetsMT platform.
Check http://www.letsmt.eu/ for more information about the LetsMT project!

There are various modules for several tasks in this collection.
Please check the short description below.
This list is most likely to change a lot in the near future and some of the modules mentioned below are not (fully) implemented yet.


=head1 COMMAND LINE TOOLS

=over

=item L<letsmt_rest|::letsmt_rest>

Command-line tool to perform common tasks via the LetsMT webservice API.

=item L<letsmt_fetch|::letsmt_fetch>

Fetch SMT training data (parallel and monolingual) from the repository according to the specifications in a configuration file.

=item L<letsmt_convert|::letsmt_convert>

Convert between different file formats.

=item L<letsmt_import|::letsmt_import>

Validate/convert/import data files that have been uploaded to LetsMT. It can also be used to import OPUS corpora from command-line.

=item L<letsmt_tokenize|::letsmt_tokenize> & L<letsmt_detokenize|::letsmt_detokenize>

Tokenize and de-tokenize a text.

=back

=cut

use strict;

use vars qw($VERSION);
$VERSION = '55';

use File::ShareDir;
use Log::Log4perl qw(get_logger :levels);

# DBMS for resource repository managers
# can be either mysql (using persistent objects) or tc (TokyoCabinet)
our $RR_MANAGER_DBMS = $ENV{PERMISSION_DBMS} || 'tt';
our $META_MANAGER_DBMS = $ENV{METADATA_DBMS} || 'tt';

# TokyoTyrant server connection, GroupDB
our $TT_GROUP_HOST = $ENV{GROUP_DB_HOST} || 'localhost';
our $TT_GROUP_PORT = $ENV{GROUP_DB_PORT} || 1979;

# TokyoTyrant server connection, MetaDB
our $TT_META_HOST = $ENV{META_DB_HOST} || 'localhost';
our $TT_META_PORT = $ENV{META_DB_PORT} || 1980;

# default sub-directories in svn repositories
our $REPOSITORY_UPLOAD_DIR = 'uploads';
our $PUBLIC_GROUP = 'public';

# SVN server settings
our $SVN_USER = 'www-data';
our $SVN_PASSWORD = $ENV{SVN_PASSWORD} || 'svn!letsmt';


# log4perl configuration
our $LOG4PERLCONF = ($ENV{LOG4PERLCONF} && -f $ENV{LOG4PERLCONF}) ?
    $ENV{LOG4PERLCONF} : 
    &File::ShareDir::dist_dir('LetsMT') . '/log/log4perl.conf';

# init log4perl (make them writable for everyone!)
# (but don't do it if already initialized)
my $old_umask = umask;
umask 0000;
Log::Log4perl->init_once( $LOG4PERLCONF );
umask $old_umask;




# about importing ....
our $IMPORT_REPORT_PROGRESS = 0;

# default sentence splitter
our $IMPORT_SPLITTER = 'europarl';

# default PDF conversion mode
# our $IMPORT_PDF_MODE = 'tika';
our $IMPORT_PDF_MODE = 'combined';



1;

=head1 LICENSE

LetsMT! Resource Repository is free software: you can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

LetsMT! Resource Repository is distributed in the hope that it will be
useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with LetsMT! Resource Repository.  If not, see
L<http://www.gnu.org/licenses/>.
