#!/usr/bin/perl
#-*-perl-*-

=head1 NAME

00_LetsMT.t - basic sanity checks for the LetsMT system

=head1 DESCRIPTION

This script tests the following assertions:

=over 2

=cut


use Test::More;


=item *

The module can be C<use>d.

=cut

use_ok 'LetsMT';


=item *

All the needed environment variables
(URL, directories, certificate paths, ...) are set.

=cut

ok defined $ENV{LETSMT_URL            }, 'check environment - LETSMT_URL set';
ok defined $ENV{LETSMTCONF            }, '- LETSMTCONF set';
ok defined $ENV{LETSMTDISKROOT        }, '- LETSMTDISKROOT set';
ok defined $ENV{LETSMTHOST            }, '- LETSMTHOST set';
ok defined $ENV{LETSMTLOG_DIR         }, '- LETSMTLOG_DIR set';
ok defined $ENV{LETSMTPORT            }, '- LETSMTPORT set';
ok defined $ENV{LETSMTROOT            }, '- LETSMTROOT set';
ok defined $ENV{LETSMTUSER            }, '- LETSMTUSER set';
ok defined $ENV{LETSMTVIRTHOSTFILE    }, '- LETSMTVIRTHOSTFILE set';
ok defined $ENV{LETSMT_CACERT         }, '- LETSMT_CACERT set';
ok defined $ENV{LETSMT_CONNECT        }, '- LETSMT_CONNECT set';
ok defined $ENV{LETSMT_CONNECT_RAW    }, '- LETSMT_CONNECT_RAW set';
ok defined $ENV{LETSMT_MODPERL_STARTUP}, '- LETSMT_MODPERL_STARTUP set';
ok defined $ENV{LETSMT_USERCERT       }, '- LETSMT_USERCERT set';
ok defined $ENV{LETSMT_USERCERTPASS   }, '- LETSMT_USERCERTPASS set';
ok defined $ENV{LETSMT_USERKEY        }, '- LETSMT_USERKEY set';

ok defined $ENV{GROUP_DB_HOST         }, '- GROUP_DB_HOST set';
ok defined $ENV{GROUP_DB_PORT         }, '- GROUP_DB_PORT set';
ok defined $ENV{META_DB_HOST          }, '- META_DB_HOST set';
ok defined $ENV{META_DB_PORT          }, '- META_DB_PORT set';

=back

=cut

done_testing;


=head1 LICENSE

This file is part of LetsMT! Resource Repository.

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
<http://www.gnu.org/licenses/>.
