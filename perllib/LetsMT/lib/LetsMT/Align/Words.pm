package LetsMT::Align::Words;

=head1 NAME

LetsMT::Align::Words - word alignment

=head1 DESCRIPTION

A factory class to return an object instance of a selected alignment module.

=cut

use strict;

use DB_File;
use DBM_Filter;

use LetsMT::Align::Words::Eflomal;


=head1 CONSTRUCTOR

 $aligner = new LetsMT::Align::Words

=cut

sub new {
    my $class = shift;
    return new LetsMT::Align::Words::Eflomal(@_);
}


sub alg2db{
    my $algfile = shift(@_);
    my $idx     = shift(@_);
    my $dbfile  = shift(@_);

    my %links=();
    my $db = tie %links,"DB_File",$dbfile;
    $db->Filter_Key_Push('utf8');
    $db->Filter_Value_Push('utf8');

    open F,"<",$algfile || return 0;
    my $i=0;
    while (<F>){
	chomp;
	my $key = $$idx[$i]."\n";
	my @alg = split(/\s/);
	my @new = ();
	foreach (@alg){
	    my ($s,$t) = split(/\-/);
	    $s++;$t++;
	    push (@new,"$s-$t");
	}
	## NOTE: idx has a final newline to work with IDA
	$links{$$idx[$i]."\n"} = join(' ',@new);
	$i++;
    }
    close F;
    untie %links;

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
