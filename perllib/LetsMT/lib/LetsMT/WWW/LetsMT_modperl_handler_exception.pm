package LetsMT::WWW::LetsMT_modperl_handler_exception;

=head1 NAME

LetsMT::WWW::LetsMT_modperl_handler_exception - Apache2 mod_perl exception handler


=head1 METHOD

=head2 C<AUTOLOAD()>

For signal handling - this subroutine is used to generate custom die() arguments.

Returns: nothing

=cut

sub AUTOLOAD {
    no strict 'refs', 'subs';
    if ( $AUTOLOAD =~ /.*::([A-Z]\w+)$/ ) {
        my $exception = $1;
        *{$AUTOLOAD} = sub {
            shift;
            bless {@_},
                "LetsMT::WWW::LetsMT_modperl_handler_exception::$exception";
        };
        goto &{$AUTOLOAD};
    }
    else {
        die "No such exception class: $AUTOLOAD\n";
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