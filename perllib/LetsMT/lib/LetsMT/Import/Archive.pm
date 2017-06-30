package LetsMT::Import::Archive;

=head1 NAME

LetsMT::Import::Archive

=head1 DESCRIPTION

Tools for importing archives (not very much so far ...).

=cut

use strict;


=head1 FUNCTIONS

=head2 C<move_log_info>

 move_log_info ($resource, $path, $count, $status)

Move import log messages to new fields
(numbered by C<$count>).

=cut

sub move_log_info {
    my ( $resource, $path, $count, $status ) = @_;
    my $xml      = &LetsMT::WebService::get_meta($resource);
    my $parser   = new XML::LibXML;
    my $dom      = $parser->parse_string($xml);
    my $logmsg   = $dom->findvalue('//import_log');
    my $logfiles = $dom->findvalue('//import_logfiles');
    &LetsMT::WebService::del_meta(
        $resource,
        import_log      => '',
        import_logfiles => ''
    );
    &LetsMT::WebService::post_meta(
        $resource,
        "status_"          . $count => $status,
        "import_"          . $count => $path,
        "import_log_"      . $count => $logmsg,
        "import_logfiles_" . $count => $logfiles
    );
}


=head2 C<delete_log_info>

 delete_log_info ($resource)

Remove loginfo for individual imports
--> useful for initialization of new imports.

=cut

sub delete_log_info {
    my ($resource) = @_;
    my $xml        = &LetsMT::WebService::get_meta($resource);
    my $parser     = new XML::LibXML;
    my $dom        = $parser->parse_string($xml);

    my %import_attr = ();
    my ($entry)     = $dom->findnodes('//list/entry');
    my @nodes       = $entry->childNodes();
    foreach my $n (@nodes) {
        my $name = $n->nodeName;
        if ( $name =~ /^(status|import)\_/ ) {
            $import_attr{$name} = '';
        }
    }
    if ( keys %import_attr ) {
        &LetsMT::WebService::del_meta( $resource, %import_attr );
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