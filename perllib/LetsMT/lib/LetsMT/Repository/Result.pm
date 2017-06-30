package LetsMT::Repository::Result;

=head1 NAME

LetsMT::Repository::Result - Object that holds and returns the XML result

=head1 DESCRIPTION

This class stores the result that every API function call returns in hash. The
constructor takes kes/value pairs as arguements and sets them as properties.
The get_xml_result function returns a XML formated string reference.

=cut

use strict;
use warnings;
use parent 'XML::Simple';

use open qw(:std :utf8);

use URI::Escape;

use Data::Dumper;
use Log::Log4perl qw(get_logger :levels);


=head1 CONSTRUCTOR

 LetsMT::Repository::Result->new ( %list )

The constructor takes a hash style list as parameter.

=cut

### CLASS METHOD ############################################################
# Usage      : LetsMT::Repository::Result->new( LIST );
# Purpose    : Constructor
# Returns    : Result object
# Parameters : list with type, code, operator, location, message, lists
# Throws     : no exceptions
# Comments   : none
# See Aslo   : N/A

sub new {
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;

    my $self = {
        type      => 'ok',
        code      => 0,
        operation => '',
        status    => '200',
        location  => '',
        message   => '',
        lists     => undef,    #passed as references
        @_,                    #overwrites previous defaults with arguments
    };

    return bless $self, $class;
}


=head1 METHODS

=head2 C<get_xml_result>

Return a reference to formatted XML format

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::Result->get_xml_result();
# Purpose    : Returns the data of the object as ref to formatted XML string
# Returns    : Reference to string in XML format
# Parameters : none
# Throws     : no exceptions
# Comments   :

sub get_xml_result {
    my $self = shift;

    if ( ref( $self->{lists} ) && ${ $self->{lists} }->{path} ) {
        ${ $self->{lists} }->{path} = uri_unescape( ${ $self->{lists} }->{path} );
    }

    # Build hash structure for XML output
    my $hash_structure = {
        'version' => $LetsMT::VERSION,
        'status'  => {
            'type'      => $self->{type},
            'code'      => $self->{code},
            'operation' => $self->{operation},
            'location'  => $self->{location},
            'content'   => $self->{message},
        },
        'list' => ref( $self->{lists} ) ? ${ $self->{lists} } : undef,
    };

    # Get parser and write out to XML
    my $xmlParser = XML::Simple->new;
    my $xml       = $xmlParser->XMLout(
        $hash_structure,
        RootName      => 'letsmt-ws',
        SuppressEmpty => 1
    );

    return \$xml;
}


=head2 C<set_values>

 &$result->set_values (%list)

Set or overwrite member variables in Result object.

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::Result->set_values( LIST );
# Purpose    : Sets or overwrites member variables in Result object
# Returns    : nothing
# Parameters : List of values to be set, like: type => 'ok', error => 0, ...
# Throws     : no exceptions
# Comments   :

sub set_values {
    my $self   = shift;
    my $values = {@_};

    # join member variables and argument values as hashes
    %$self = ( %$self, %$values );
}


=head2 C<success>

Check if result type is 'ok'.

=cut

### INSTANCE METHOD #########################################################
# Usage      : LetsMT::Repository::Result->success;
# Purpose    : returns 1 if result type eq 'ok'
# Returns    : boolean
# Parameters : nothing
# Throws     : no exceptions
# Comments   :

sub success {
    my $self = shift;
    return 1 if ( $self->{type} eq 'ok' );
    return 0;
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