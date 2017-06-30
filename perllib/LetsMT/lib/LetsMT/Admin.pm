package LetsMT::Admin;

=head1 NAME

LetsMT::Admin

=cut

use strict;

use XML::Simple;
use File::Temp 'tempdir';

use LetsMT::Repository::StorageManager;

use LetsMT::Resource;
use LetsMT::WebService;
use LetsMT::Corpus;

our $VERBOSE = 0;

# list all slots and their branches

sub list_slots {
    my %slots    = ();
    my %branches = ();

    my ( $nr_slots, $nr_branches, $nr_empty )
        = &get_slots( \%slots, \%branches );
    print STDERR
        "INFO: $nr_slots slots with $nr_branches branches found ($nr_empty empty slots)\n";

    foreach my $slot ( keys %branches ) {
        print "$slot\n";
        foreach my $branch ( keys %{ $branches{$slot} } ) {
            print "    $branch\n";
        }
    }
}


# list all files in a slot

sub list_files {
    my ( $slot, $branch, $dir ) = @_;

    my %slots    = ();
    my %branches = ();

    &get_repo_objects( $slot, $branch, \%slots, \%branches );

    # list all files for all selected slots/branches

    foreach my $s ( keys %branches ) {
        print "  SLOT: $s\n";
        foreach my $b ( keys %{ $branches{$s} } ) {
            print "BRANCH: $b\n";
            my @files = ();
            get_files_recursive( \@files, $slots{$s}, $branches{$s}{$b},
                                 $dir );
            print join( "\n", map { $_ = '  FILE: ' . $_ } @files );
            print "\n";
        }
    }
}

# check whether all files have metadata

# slot ..... slot name [optional]
# branch ... branch name [optional]
# dir ...... relative path in slot/branch [optional]
# repair ... flag = 1 --> try to repair meta data if possible

sub check_meta {
    my ( $slot, $branch, $dir, $repair ) = @_;

    my %slots    = ();
    my %branches = ();

    &get_repo_objects( $slot, $branch, \%slots, \%branches );

    foreach my $s ( keys %branches ) {
        foreach my $b ( keys %{ $branches{$s} } ) {
            &check_meta_in_branch( $s, $b, $dir, $repair, $slots{$s},
                $branches{$s}{$b} );
        }
    }
}

# check meta data in a specific branch (and dir if given)

sub check_meta_in_branch {
    my $slot      = shift;
    my $branch    = shift;
    my $dir       = shift;
    my $repair    = shift;
    my $slotobj   = shift || &get_slot( name => $slot );
    my $branchobj = shift || &get_branch( name => $branch, slot => $slot );

    if ( !$slotobj ) {
        print STDERR "WARNING: no slot $slot found!\n";
        return 0;
    }
    if ( !$branchobj ) {
        print STDERR "WARNING: no branch $slot/$branch found!\n";
        return 0;
    }

    print STDERR "INFO: check slot $slot/$branch!\n";
    print STDERR "INFO: Find all files\n";

    my @files = ();
    &get_files_recursive( \@files, $slotobj, $branchobj, $dir );
    print STDERR "\nINFO: Now check whether metadata is set for all files!\n";

    my $empty=0;
    foreach my $f (@files) {
        my $resource = &LetsMT::Resource::make($slot, $branch, $f);
        my $xml = &LetsMT::WebService::get_meta($resource);

        # $metaDB->open('/opt/letsmt_diskroot_v3/joerg/metadata.tct');
        # my $data = $metaDB->get($path);
        # $metaDB->close();

        my $ok = 1;
        my $path = join( '/', ( $slot, $branch, $f ) );
        if ( not $xml ) {
            print STDERR "nothing returned for $path\n";
            $ok = 0;
        }
        my $data = XMLin($xml);

        #            my $data = XMLin($xml,ForceArray=>['entry']);
        if ( ref($data) ne 'HASH' ) {
            print STDERR "\nWARNING: nothing returned for $path\n";
            $ok = 0;
        }
        elsif ( ref( $$data{list} ) ne 'HASH' ) {
            print STDERR "\nWARNING: no meta data found for $path\n";
            $ok = 0;
        }
        elsif ( ref( $$data{list}{entry} ) ne 'HASH' ) {
            print STDERR "\nWARNING: no meta data found for $path\n";
            $ok = 0;
        }

        if ($ok) { print STDERR "."; }
        elsif ($repair) {
            ###############
            # try to repair meta-data ......
            print STDERR " try to set metadata automatically ....\n";
            &repair_meta( $slot, $branch, $f, $data );
        }
        $empty++ unless ($ok);
    }
    if ($repair){
        print STDERR "\n$empty meta-data records added\n";
    }
    else{
        print STDERR "\nNr of files without meta-data: $empty\n";
    }
}

# TODO: check if this is safe enough ....
# try to automatically set meta-data

sub repair_meta {
    my ( $slot, $branch, $path, $olddata ) = @_;
    my $tmpdir = tempdir(
        'admin_XXXXXXXX',
        DIR     => '/tmp',
        CLEANUP => 1
    );
    my $resource = &LetsMT::Resource::make( $slot, $branch, $path, $tmpdir );
    my %meta = default_meta($resource);
    &LetsMT::WebService::post_meta( $resource, %meta );
    File::Temp::cleanup();
}

# TODO: integrate type-check in Resource.pm?!?

sub default_meta {
    my $resource = shift;
    my @elems    = split( /\/+/, $resource->path );
    my %meta     = ();
    if ( $elems[0] eq 'xml' ) {    # corpus directory
        if ( $elems[1] =~ /^(..)-(..)$/ ) {    # sentence alignments
            my ( $src, $trg ) = ( $1, $2 );
            if ( $elems[-1] =~ /\.xml$/ ) {    # alignment file in xml
                $meta{language}          = "$src,$trg";
                $meta{'source-language'} = $src;
                $meta{'target-language'} = $trg;
                $meta{'resource-type'}   = 'sentalign';
                $meta{kind}              = 'sentalign';
                $meta{status}            = 'metadata repaired';
                $meta{size}              = sentalign_size($resource);
            }
        }
        elsif ( $elems[1] =~ /^(..)$/ ) {      # sentence alignments
            my $lang = $1;
            if ( $elems[-1] =~ /\.xml$/ ) {    # alignment file in xml
                $meta{language}        = $lang;
                $meta{'resource-type'} = 'corpusfile';
                $meta{kind}            = 'corpusfile';
                $meta{status}          = 'metadata repaired';
                $meta{size}            = corpus_size($resource);
            }
        }
    }
    return %meta;
}

# TODO: is the count command safe enough?
# TODO: use cat instead of download to avoid temp-files ...!?

sub sentalign_size {
    my $resource = shift;
    if ( &LetsMT::WebService::get_resource($resource) ) {
        my $file = $resource->local_path;
        my $size = `grep "<link " $file | wc -l`;
        return $size + 0;
    }
}

# TODO: is the count command safe enough?

sub corpus_size {
    my $resource = shift;
    if ( &LetsMT::WebService::get_resource($resource) ) {
        my $file = $resource->local_path;
        my $size = `grep "</s>" $file | wc -l`;
        return $size + 0;
    }
}

# toogle verbose output flag

sub verbose_output {
    $VERBOSE = not $VERBOSE;
}

# get all files in the repository recursively

sub get_files_recursive {
    my ( $files, $slotobj, $branchobj, $current_dir ) = @_;
    my @dirs = split( /\/+/, $current_dir );
    my @list = &LetsMT::Repository::StorageManager::_filelist( $slotobj,
        $branchobj, \@dirs );

    $files = [] if ( ref($files) ne 'ARRAY' );

    foreach my $xml (@list) {
        my $data = XMLin( $xml, ForceArray => ['entry'] );
        if ( ref($data) eq 'HASH' ) {
            if ( ref( $$data{entry} ) eq 'HASH' ) {
                foreach my $f ( keys %{ $$data{entry} } ) {
                    if ( ref( $$data{entry}{$f} ) eq 'HASH' ) {
                        push( @dirs, $f );
                        if ( $$data{entry}{$f}{kind} eq 'dir' ) {
                            if ($VERBOSE) {
                                print STDERR "find files in ",
                                join( '/', @dirs ), "\n";
                            }
#                            else { print STDERR "."; }
                            &get_files_recursive( $files, $slotobj,
                                                  $branchobj, 
                                                  join( '/', @dirs ) );
                        }
                        else {
                            push( @{$files}, join( '/', @dirs ) );
                        }
                        pop(@dirs);
                    }
                }
            }
        }
    }
    return $#{$files} + 1;
}

# get all subdirectories in the repository in xml/

sub get_xml_dirs {
    my ( $slotobj, $branchobj ) = @_;
    my @list = &LetsMT::Repository::StorageManager::_filelist( $slotobj,
        $branchobj, ['xml'] );
    my @dirs = ();
    foreach my $xml (@list) {
        my $data = XMLin( $xml, ForceArray => ['entry'] );
        if ( ref($data) eq 'HASH' ) {
            if ( ref( $$data{entry} ) eq 'HASH' ) {
                push( @dirs, keys %{ $$data{entry} } );
            }
        }
    }
    return @dirs;
}

# if $slot ---> get specific slot object
# if $slot & branch ---> get specific branch object
# otherwise: get all slots with all branches!

sub get_repo_objects {
    my ( $slot, $branch, $slots, $branches ) = @_;

    if ($slot) {
        $$slots{$slot} = &get_slot($slot);
        if ($branch) {
            $$branches{$slot}{$branch} = &get_branch( $slot, $branch );
        }
        else {
            &get_branches( $branches, $slot );
        }
    }
    else {
        my ( $nr_slots, $nr_branches, $nr_empty )
            = &get_slots( $slots, $branches );
        print STDERR
            "INFO: $nr_slots slots with $nr_branches branches found ($nr_empty empty slots)\n";
    }
}

# return slot object

sub get_slot {
    my $slot = shift;
    return &LetsMT::Repository::StorageManager::_get_slot( name => $slot );
}

# return branch object

sub get_branch {
    my ( $slot, $branch ) = @_;
    return &LetsMT::Repository::StorageManager::_get_branch(
        name           => $branch,
        slot           => $slot,
        superuser_view => 1
    );
}

# get all branches in a given slot

sub get_branches {
    my ( $branches, $slot ) = @_;
    my $branchobj = &LetsMT::Repository::StorageManager::_get_branch(
        slot           => $slot,
        superuser_view => 1
    );
    my $count = 0;
    do {
        my $branch = $branchobj->name;
        $$branches{$slot}{$branch} = $branchobj;
        $count++;
    } while ( $branchobj->restore_next() );
    return $count;
}

# get all slots and all branches in the repository

sub get_slots {
    my $slots    = shift;
    my $branches = shift;

    my $slot_count       = 0;
    my $empty_slot_count = 0;
    my $branch_count     = 0;

    my $slotobj = &LetsMT::Repository::StorageManager::_get_slot();
    do {
        my $slot = $slotobj->name;
        $$slots{$slot}
            = &LetsMT::Repository::StorageManager::_get_slot( name => $slot );
        $slot_count++;
        if (my $branchobj = &LetsMT::Repository::StorageManager::_get_branch(
                slot           => $slot,
                superuser_view => 1
            )
            )
        {
            do {
                my $branch = $branchobj->name;
                $$branches{$slot}{$branch} = $branchobj;
                $branch_count++;
            } while ( $branchobj->restore_next() );
        }
        else { $empty_slot_count++; }
    } while ( $slotobj->restore_next() );
    return ( $slot_count, $branch_count, $empty_slot_count );
}


sub find_parallel_documents{
    my ($slot,$user) = @_;

    my $corpus = &LetsMT::Resource::make($slot, $user);

    my %para = (skip_aligned => 1,
                search_parallel => 'similar',
                search_parallel_min_size_ratio => 0.5,
                search_parallel_min_name_match => 0.5);
    my %parallel = LetsMT::Corpus::find_all_parallel($corpus,%para);

    foreach my $file1 (keys %parallel){
        print $file1,"\n";
        foreach my $lang (keys %{$parallel{$file1}}){
            ## matching document sorted by match-score
            my @matches = sort {
                $parallel{$file1}{$lang}{$b}{match}
                <=>
                $parallel{$file1}{$lang}{$a}{match}
            }
            keys %{$parallel{$file1}{$lang}};
            foreach (@matches){
                printf "  %4.3f (%3.2f,%3.2f) %s\n",
                    $parallel{$file1}{$lang}{$_}{match},
                    $parallel{$file1}{$lang}{$_}{name_match},
                    $parallel{$file1}{$lang}{$_}{size_match},
                    $_;
            }
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