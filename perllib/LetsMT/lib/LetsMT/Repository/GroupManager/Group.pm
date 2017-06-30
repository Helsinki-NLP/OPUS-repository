package LetsMT::Repository::GroupManager::Group;

=head1 NAME

LetsMT::Repository::GroupManager::Group - persistent object class for LetsMT's GroupManager

=cut

use strict;
use parent 'LetsMT::Repository::Persist';

use Log::Log4perl qw(get_logger :levels);
use LetsMT::Repository::Err;

my %persist_def = (
    fields => {
        grp     => { type => 'varchar(128) NOT NULL', prim => 1 },
        creator => { type => 'varchar(128) NOT NULL' },
    }
);

my @quote_attrs    = ( 'grp', 'creator' );
my @nonquote_attrs = ();
my @attrs          = ( @quote_attrs, @nonquote_attrs );

#####################################################
#### PUBLIC CLASS METHODS ###########################
#####################################################

#### Optional arg: $grp

=head1 CONSTRUCTOR

 $gm = new LetsMT::Repository:GroupManager:Group ($class, $grp, $creator)

Tries to create a new object. Fails if it already exists.

Returns: a Group object.

=cut

sub new {
    my ( $class, $grp, $creator ) = @_;
    my $self = $class->SUPER::new();

    map { $self->{$_} = $persist_def{$_} } keys %persist_def;

    eval { $self->SUPER::initialize(); };

    if ($@) {
        raise( 7, $@ . "group $grp", 'error' );
    }

    if ( $grp && $creator ) {

        unless (
            $self->init_instance(
                qq{grp = '$grp' AND creator = '$creator'},
                map { $_ => eval '$' . $_ } (@attrs)
            )
            )
        {
            raise( 4, "Group '$grp'", 'warn' );
        }
    }

    return $self;
}


=head1 METHODS

=head2 C<get_idquery>

 $string = $gm->get_idquery ($grp)

Returns: an SQL-query to be used by retrieve()

=cut

sub get_idquery {
    my ($grp) = @_;

    return "grp = '$grp'";
}


=head2 C<drop_table>

Drop the Group table.

Returns: nothing

=cut

sub drop_table {
    my $obj = new LetsMT::Repository::GroupManager::Group();
    $obj->SUPER::drop_table();
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