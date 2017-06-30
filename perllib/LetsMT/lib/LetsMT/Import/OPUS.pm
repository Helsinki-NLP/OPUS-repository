package LetsMT::Import::OPUS;

=head1 NAME

LetsMT::Import::OPUS - import handler for I<OPUS> corpus data

=head1 DESCRIPTION

L<OPUS|http://opus.lingfil.uu.se>: an open parallel corpus.

A child of L<LetsMT::Corpus|LetsMT::Corpus>.

=cut

use strict;
use parent 'LetsMT::Corpus';

use LetsMT;
use LetsMT::Resource;
use LetsMT::WebService;
use LetsMT::Tools qw/:all/;

use File::Basename;
use File::Temp qw(tempfile tempdir);

use Log::Log4perl qw(get_logger :levels);


=head1 CONSTRUCTOR

 $opus = new LetsMT::Import::OPUS (%OPTIONS)

OPTIONS:

 -rest_home (default: LETSMT_URL)
 -opus_home (default: '/home/opus/OPUS/corpus/')
 ...

=cut

sub new {
    my $class = shift;
    my %attr  = @_;

    my $self = {};
    bless $self, $class;

    foreach ( keys %attr ) {
        $self->{$_} = $attr{$_};
    }

    $self->{RESTHOME} = $attr{-rest_home} || $ENV{LETSMT_URL};
    $self->{OPUSHOME} = $attr{-opus_home} || '/home/opus/OPUS/corpus/';

    return $self;
}


=head1 METHODS

=head2 C<import_corpus>

 $opus->import_corpus ($corpus, $destination, $user)

Import corpus from C<opus_home>/C<$corpus> into LetsMT/C<$destination>/C<$user>.

=cut

sub import_corpus {
    my $self = shift;
    my ( $corpus, $destination, $user ) = @_;

    $| = 1;
    $self->{DONE} = {};    # store file names that have been imported already!

    my %meta = (
        'origin'      => 'OPUS',
        'gid'         => 'public',
        'import-date' => time(),
    );

    # reset language hashs
    $self->{'parallel-langs'}={};
    $self->{'langs'}={};

    if ( !&LetsMT::WebService::user_exists( $user, 'public', 'admin' ) ) {
        &LetsMT::WebService::post_group( 'public', $user, 'admin' )
            || get_logger(__PACKAGE__)->warn("cannot create user '$user' in group 'public'!");
    }

    my $resource = &LetsMT::Resource::make( $destination, $user );
    if ( !&LetsMT::WebService::resource_exists($resource) ) {
        &LetsMT::WebService::post( $resource, %meta )
            # &LetsMT::WebService::post_letsmt($resource, %meta)
            || get_logger(__PACKAGE__)
            ->error("cannot create slot '$destination'!") && exit 1;
    }

    chdir "$self->{OPUSHOME}/$corpus/xml";
    my @sentalign = glob("*.xml.gz");

    foreach my $alg (@sentalign) {
        # skip align-files ---> import only the global sentalign file
        if ( $self->{-skip_align_files} ) {
            print "import $alg ... ";
            $self->import_sentalign( $alg, $corpus, $destination, $user );
            print " done!\n";
        }

        # otherwise: import all individual files
        else {
            my $langpair = $alg;
            $langpair =~ s/\.xml.gz//;
            my @align = `find $langpair -name '*.xml.gz'` if ( -d $langpair );
            if (@align) {
                print "import ", scalar @align, " sentalign files ($langpair) ";
                foreach my $a (@align) {
                    $self->import_sentalign( $a, $corpus, $destination,
                        $user );
                }
            }

            # no individual files found: import the global file anyway!
            else {
                print "import $alg ... ";
                $self->import_sentalign( $alg, $corpus, $destination, $user );
                print " done!\n";
            }
        }
        print " done!\n";
    }

    LetsMT::WebService::put_meta(
        $resource,
        'resource-type'  => 'branch',
        'parallel-langs' => join( ',', keys %{$self->{'parallel-langs'}} ),
        'langs'          => join( ',', keys %{$self->{'langs'}} )
    );
}


=head2 C<import_sentalign>

 $opus->import_sentalign ($alignfile, $corpus, $destination, $user)

=cut

sub import_sentalign {
    my $self = shift;
    my ( $alignfile, $corpus, $destination, $user ) = @_;

    return 1 if ( exists $self->{DONE}->{$alignfile} );

    my @elems = split( '/', $alignfile );
    my $langpair;
    if ($#elems) {
        $langpair = shift(@elems);
    }
    else {
        $langpair = $alignfile;
        $langpair =~ s/\.xml(.gz)?$//;
    }
    my ( $src, $trg ) = split( '-', $langpair );
    my $basename = join( '/', @elems );
    $basename =~ s/\.gz$//;

    # target name of the sentence alignment file
    my $path = 'xml/' . $langpair . '/' . $basename;
    my $name = $destination . '/' . $path;

    # check whether the resource exists already
    # (TODO: right now I only check if the file exists)
    #        better check if the actual file has the same size ....)
    if ( not $self->{-overwrite} ) {
        my $resource = &LetsMT::Resource::make( $destination, $user, $path );
        if ( &LetsMT::WebService::resource_exists($resource) ) {
            print "x";
            $self->{'langs'}->{$src}=1;
            $self->{'langs'}->{$trg}=1;
            return 1;
        }
    }

    open F, "gzip -cd < $alignfile |"
        || get_logger(__PACKAGE__)->error("cannot open file $alignfile")
            && exit 1;
    my ( $fh, $filename ) = tempfile(
        'opusXXXXXX',
        UNLINK => 1,
    );

    my ( $srcdoc,  $trgdoc );
    my ( $srcdest, $trgdest );

    my $count = 0;
    my $ok    = 1;
    while (<F>) {
        if (/fromDoc\=\"(.*?)\"/) {
            $srcdoc = $1;
            my $srcfile = $srcdoc;
            $srcfile =~ s/\.gz$//;
            $srcdest = 'xml/' . $srcfile;

            s/fromDoc\=\"(.*?)\"/fromDoc=\"$srcfile\"/;
            $ok = $self->import_corpusfile( $srcdoc, $destination, $srcdest,
                $src, $user );
        }
        if (/toDoc\=\"(.*?)\"/) {
            $trgdoc = $1;
            my $trgfile = $trgdoc;
            $trgfile =~ s/\.gz$//;
            $trgdest = 'xml/' . $trgfile;

            s/toDoc\=\"(.*?)\"/toDoc=\"$trgfile\"/;
            $ok *= $self->import_corpusfile( $trgdoc, $destination, $trgdest,
                $trg, $user );
        }
        $count++ if (/\<link /);
        print $fh $_;

        # print $fh $_ if ($ok);
    }
    close $fh;

    my %meta = (
        'size'            => $count,
        'source-language' => $src,
        'target-language' => $trg,
        'language'        => "$src,$trg",
        'origin'          => 'OPUS',
        'resource-type'   => 'sentalign',
        'status'          => 'imported'
    );

    print ".";
    $self->{DONE}->{$alignfile} = 1;

    my $resource = &LetsMT::Resource::make( $destination, $user, $path );

    #    if (&LetsMT::WebService::put_letsmt_file( $resource, $filename )){
    if ( LetsMT::WebService::put_file( $resource, $filename ) ) {
        LetsMT::WebService::put_meta( $resource, %meta )
            || get_logger(__PACKAGE__)->warn("cannot set metadata for resource '$resource'!");
        $self->{'parallel-langs'}->{"$src-$trg"}=1;
        return 1;
    }
    else {
        get_logger(__PACKAGE__)->warn("cannot update resource '$resource'!");
        return 0;
    }
}


=head2 C<import_corpusfile>

 $opus->import_corpusfile ($corpusfile, $slot, $destination, $lang, $user)

=cut

sub import_corpusfile {
    my $self = shift;
    my ( $corpusfile, $slot, $destination, $lang, $user ) = @_;

    return 1 if ( exists $self->{DONE}->{$corpusfile} );

    # skip uploading if the file exists already
    if ( not $self->{-overwrite} ) {
        my $resource = &LetsMT::Resource::make( $slot, $user, $destination );
        if ( &LetsMT::WebService::resource_exists($resource) ) {
            print "X";
            $self->{'langs'}->{$lang}=1;
            return 1;
        }
    }

    my $file = $corpusfile;
    if    ( -e "../raw/$file" )    { $file = "../raw/$file"; }
    elsif ( -e "../raw/$file.gz" ) { $file = "../raw/$file.gz"; }
    elsif ( -e "$file.gz" )        { $file = "$file.gz"; }

    return 0 unless ( -e $file );

    if ( $file =~ /\.gz$/ ) {
        my $dir = tempdir(
            'opus_import_XXXXXXXX',
            DIR     => '/tmp',
            CLEANUP => 1,
        );
        my $tmpfile = "$dir/corpus.xml";
#        LetsMT::Tools::safe_system("gzip -cd $file > $tmpfile");
        pipe_out_cmd($tmpfile, 'gzip', '-cd', $file);
        $file = $tmpfile;
    }
    my $size = `grep '</s>' $file | wc -l`;
    $size =~ s/\s//gs;

    # need to unpack, count sentences ...
    my %meta = (
        size            => $size,
        language        => $lang,
        'origin'        => 'OPUS',
        'resource-type' => 'corpusfile',
        'status'        => 'imported'
    );

    print "*";
    $self->{DONE}->{$corpusfile} = 1;

    my $resource = &LetsMT::Resource::make( $slot, $user, $destination );

    if ( &LetsMT::WebService::put_file( $resource, $file ) ) {
        $self->{'langs'}->{$lang} = 1;
        &LetsMT::WebService::put_meta( $resource, %meta )
            || get_logger(__PACKAGE__)
            ->warn("cannot add metadata to resource '$resource'!");
        return 1;
    }
    else {
        get_logger(__PACKAGE__)->warn("cannot update resource '$resource'!");
        return 0;
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