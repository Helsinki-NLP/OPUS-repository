package LetsMT::Export::Reader::Corpus;

=head1 NAME

LetsMT::Export::Reader::Corpus - reader for corpus data

=cut

use strict;
use File::Temp 'tempdir';

use Log::Log4perl qw(get_logger :levels);

use LetsMT::Tools;
use LetsMT::Export::Reader;
use LetsMT::Resource;


=head1 CONSTRUCTOR

=cut

sub new {
    my $class = shift;
    my %self  = ( LID => 0, @_);

    bless \%self, $class;
    return \%self;
}


=head1 METHODS

=head2 C<fetch>

=cut

sub fetch{
    my $self = shift;
    my $resource = shift;
    if ( (! -e $resource->local_path) || $self->{-always_fetch}){
	my $tmphome = $ENV{LETSMT_TMP} || '/tmp';
	my $tmpdir = tempdir(
	    'fetch_XXXXXXXX',
	    DIR     => $tmphome,
	    CLEANUP => 1,
	    );
	$resource->local_dir($tmpdir);
        unless ( &LetsMT::WebService::get_resource($resource) ) {
            get_logger(__PACKAGE__)->error("Unable to fetch '$resource'");
            return 0;
        }
    }
    return 1;
}


=head2 C<open>

=cut

sub open{
    my $self     = shift;
    my $resource = shift || $self->{resource};
    my %para     = @_;

    # save base-resource (for cloning later when creating reader objects)
    $self->{BaseResource} = $resource;

    # set additional parameters
    foreach (keys %para){ $self->{$_} = $para{$_}; }

    # save parameters in a separate hash (for opening individual reader-obj's)
    %{$self->{OPEN_PARA}} = %para;

    # Get requested resource if necessary
    $self->fetch($resource) || return 0;

    # check if the corpus is a complete parallel corpus
    # yes? --> fetch monolingual corpora
    if ($self->{download_all_mono}){
        my $NewResource = $resource->path_down(); # remove last part of path
        if ($NewResource->path eq 'xml'){         # remaining path = 'xml'?
            my @langs = $resource->language();    # > 1 language (=parallel)
            if ($#langs){
                foreach my $l (@langs){
                    $NewResource->path($NewResource->path().'/'.$l);
                    $self->fetch($NewResource);
                    $NewResource = $resource->path_down();
                }
            }
        }
    }

    # get all xml files from the current resource

    my $LocalPath = $resource->local_path;  # need to replace local path
    my $ResourcePath = $resource->path;     # with resource path

    my @files = &LetsMT::Tools::find_files('\.xml$',$resource->local_path);
    map {substr($_,0,length($resource->local_path),$resource->path) } @files;
    @{$self->{FILES}} = @files;

    return $self->open_next();
}


=head2 C<open_next>

=cut

sub open_next{
    my $self = shift;

    # close previous input stream
    $self->{READER}->close if (ref($self->{READER}));

    # stop if all files have been processed
    return 0 if (not @{$self->{FILES}});

    # make a new resource object
    my $path = shift(@{$self->{FILES}});
    $self->{CurrentResource} = $self->{BaseResource}->clone;
    $self->{CurrentResource}->path($path);

    # open next resource
    $self->{READER} = new LetsMT::Export::Reader($self->{CurrentResource});
    return $self->{READER}->open(
        $self->{CurrentResource},
        %{$self->{OPEN_PARA}});
}


=head2 C<close>

=cut

sub close{
    return $_[0]->{READER}->close();
}


=head2 C<read>

=cut

sub read{
    my $self = shift;
    if (my $data = $self->{READER}->read() ){
        return $data;
    }
    return undef if (! $self->open_next());
    return $self->{READER}->read();
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
