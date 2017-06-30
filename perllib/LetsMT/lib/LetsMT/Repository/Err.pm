package LetsMT::Repository::Err;

=head1 NAME

LetsMT::Repository::Err - definition of errors, and main exception invocation subroutine

=cut

use strict;
use Switch;
use Exporter 'import';
our @EXPORT = 'raise';

use open qw(:std :utf8);

use Log::Log4perl qw(get_logger :levels);
use LetsMT::WWW::LetsMT_modperl_handler_exception;

## raise errors in the lower levels where possible,
## class methods should rely on those.

# Relevant HTTP codes
# 400 Bad Request
# 401 Unauthorized
# 403 Forbidden
# 404 Not Found
# 405 Method Not Allowed
# 406 Not Acceptable
# 408 Request Timeout
# 409 Conflict
# 410 Gone
# 415 Unsupported Media Type

# 500 Internal Server Error
# 501 Not Implemented

=head1 CODES

The following error codes are used:

  1 User already member of group [HTTP code 409]
  2 Failed to add user to group  [HTTP code 403]
 
  3 Group not found              [HTTP code 404]
 
  4 Resource exists already      [HTTP code 409]
 
  6 Cannot find/read _           [HTTP code 403]
 
  7 DB error                     [HTTP code 500]
  8 System level failure         [HTTP code 500]
 
  9 Init failure                 [HTTP code 403]
 10 Failed to create group       [HTTP code 403]
 
 11 Other error                  [HTTP code 409]
 
 12 Missing _                    [HTTP code 400]
 
 13 Not implemented              [HTTP code 501]
 
 14 Permission denied            [HTTP code 403]
 
 15 Not a valid user             [HTTP code 403]
 
 16 Failed to delete _           [HTTP code 409]
 
 17 Invalid _                    [HTTP code 400]

=cut

our %type = (
    ## user/group errors
    1 => { http => 409, msg => "User '%s' already member of group" },
    2 => { http => 403, msg => "Failed to add user '%s' to group" },

    ## invalid error
    3 => { http => 404, msg => "Group '%s' not found" },

    4 => { http => 409, msg => "%s exists already" },

    ## missing resource / read error
    6 => { http => 403, msg => "Cannot find/read %s" },

    ## other exception
    7 => { http => 500, msg => "DB error: %s" },
    8 => { http => 500, msg => "System level failure: %s" },

    9  => { http => 403, msg => "init failure %s" },
    10 => { http => 403, msg => "failed to create group %s" },

    11 => { http => 409, msg => "Other error: %s" },

    12 => { http => 400, msg => "Missing %s" },

    13 => { http => 501, msg => "Not implemented: %s" },

    14 => { http => 403, msg => "Permission denied for %s" },

    15 => { http => 403, msg => "%s not a valid user" },

    16 => { http => 409, msg => "Failed to delete %s" },

    17 => { http => 400, msg => "Invalid %s" },

);


=head1 FUNCTIONS

=head2 C<raise>

 raise( $code )
 raise( $code, $message )
 raise( $code, $message, $log_level )

Given the type code C<$code> (a hash key from the table above),
this will raise an exception describing the error and where it happened.

Returns: nothing (it raises an exception using die())

=cut

sub raise {
    my $code      = shift;
    my $msg       = shift;
    my $log_level = shift;

    $msg = sprintf( $type{$code}->{msg}, $msg );

    my $logger = get_logger(__PACKAGE__);

    switch ($log_level) {
        case /debug/i { $logger->debug( caller() . ': ' . $msg ); }
        case /info/i  { $logger->info( caller() . ': ' . $msg ); }
        case /warn/i  { $logger->warn( caller() . ': ' . $msg ); }
        case /error/i { $logger->error( caller() . ': ' . $msg ); }
        case /fatal/i { $logger->fatal( caller() . ': ' . $msg ); }
        else          { $logger->error( caller() . ': ' . $msg ); }
    }

    my ( $package, $filename, $line ) = caller;

    die LetsMT::WWW::LetsMT_modperl_handler_exception->Exception(
        code     => $code,
        http     => $type{$code}->{http},
        msg      => $msg,
        package  => $package,
        filename => $filename,
        line     => $line
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