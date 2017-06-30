
=head1 NAME

Tools

=head1 DESCRIPTION

XML-related tools

=cut

package LetsMT::Tools::XML;

use strict;

use Log::Log4perl qw(get_logger :levels);
use Data::Dumper;

use LetsMT::Tools;
use LetsMT::Lang::Encoding;

use Exporter 'import';
our @EXPORT = qw(
    validate_xml validate_dtd validate_standalone_xml
    validate_xs tidy_xml
    clean_xml clean_xml_no_copy
);
our %EXPORT_TAGS = ( all => \@EXPORT );

our $XMLLINT_MAXMEM = 256000000;     # maxmem for xmllint (256MB)
our $TIDY = `which tidy` || undef;
chomp($TIDY);


=head1 FUNCTIONS

=head2 C<validate_dtd>

 $errors = &validate_dtd ($resource, $dtd)

Validate C<$resource> according to C<$dtd>.

Returns a list of errors if it fails, and an empty list otherwise.

=cut

sub validate_dtd {
    my ( $resource, $dtd ) = @_;
    my $err_resource = $resource->graft_suffix('.dtd.err');

    my @cmd = (
        'xmllint --noout --dtdvalid ',
        &safe_path($dtd),
        ' --maxmem ',
        $XMLLINT_MAXMEM,
        ' ',
        &safe_path( $resource->local_path ),
        ' 2>&1 | ',
        "egrep -v '(Memory tag|xmlMemFree|xmlMalloc|bye)' > ",
        &safe_path( $err_resource->local_path )
    );

    die "Unable to find dtd"
        unless ( -e $dtd );
    die "Unable to run command: '", join( ' ', @cmd ), "'"
        unless ( &safe_system(@cmd) );

    if ( -s $err_resource->local_path ) {
        return ( [ $err_resource, status => 'dtd validation error log' ] );
    }
    return ();
}


=head2 C<validate_xs>

 $errors = &validate_xs ($resource, $xs)

Validate C<$resource> according to XML Schema C<$xs>. 
Returns a list of errors if it fails, and an empty list otherwise.

=cut

sub validate_xs {
    my ( $resource, $xs ) = @_;
    my $err_resource = $resource->graft_suffix('.xs.err');

    my @cmd = (
        'xmllint --noout --stream --schema ',
        &safe_path($xs),
        ' --maxmem ',
        $XMLLINT_MAXMEM,
        ' ',
        &safe_path( $resource->local_path ),
        ' 2>&1 | ',
        "egrep -v '(Memory tag|xmlMemFree|xmlMalloc|bye)' > ",
        &safe_path( $err_resource->local_path )
    );

    die "Unable to find XML Schema $xs"
        unless ( -e $xs );
    die "Unable to run command: '", join( ' ', @cmd ), "'"
        unless ( &safe_system(@cmd) );

    if ( -s $err_resource->local_path ) {
        return ( [ $err_resource, status => 'xs validation error log' ] );
    }
    return ();
}


=head2 C<validate_xml>

 $errors = &validate_xml ($resource)

Check that C<$resource> is valid XML.
This expects a DOCTYPE declaration in the document!

Returns a list of errors if it fails, and an empty list otherwise.

=cut

sub validate_xml {
    my $resource = shift;
    my $dtd_home = shift || &File::ShareDir::dist_dir('LetsMT') . '/dtd';

    my $err_resource = $resource->graft_suffix('.dtd.err');

    my @cmd = (
        'xmllint',
        ' --noout --nowarning --stream --valid',
        '--path'   => $dtd_home,
        '--maxmem' => $XMLLINT_MAXMEM,
        safe_path( $resource->local_path ),
        '2>&1 |',
        "egrep -v '(Memory tag|xmlMemFree|xmlMalloc|bye)' >",
        safe_path( $err_resource->local_path )
    );

    die "Unable to run command: '", join( ' ', @cmd ), "'"
        unless ( &safe_system(@cmd) );

    if ( -s $err_resource->local_path ) {
        return ( [ $err_resource, status => 'dtd validation error log' ] );
    }
    return ();
}


=head2 C<validate_standalone_xml>

 $errors = &validate_standalone_xml ($resource)

Check that C<$resource> is valid xml
(without DTD validation id a DOCTYPE is given in the document).

Returns a list of errors if it fails, and an empty list otherwise.

=cut

sub validate_standalone_xml {
    my ($resource) = @_;
    my $err_resource = $resource->graft_suffix('.err');

    # --nowarning: avoid warnings, for example DTD from DOCTYPES not found

    my @cmd = (
        'xmllint --noout --nowarning --stream ',
        '--maxmem' => $XMLLINT_MAXMEM,
        safe_path( $resource->local_path ),
        '2>&1 |',
        "egrep -v '(Memory tag|xmlMemFree|xmlMalloc|bye)' >",
        safe_path( $err_resource->local_path )
    );

    die "Unable to run command: '", join( ' ', @cmd ), "'"
        unless ( &safe_system(@cmd) );

    if ( -s $err_resource->local_path ) {
        return ( [ $err_resource, status => "xml validation error log" ] );
    }
    return ();
}


=head2 C<tidy_xml>

 $errors = &tidy_xml ($resource)

Validate, correct, and format (in place) the XML file found at path C<$resource>.

Returns a list of errors if it fails, and an empty list otherwise.

=cut

sub tidy_xml {
    my ($resource) = @_;
    my $err_resource = $resource->graft_suffix('.tidy.err');

    return () unless ( defined $TIDY );

    my $file     = $resource->local_path;
    my $encoding = $resource->encoding()
        || &LetsMT::Tools::get_bom_encoding($file);

    if ($encoding) {
        if ( $encoding !~ /utf\-?8/i ) {
            return () unless ( &text2utf8_inplace( $file, $encoding ) );
        }
    }

    # run tidy and grep for errors
    my @cmd = (
        $TIDY,
        '-m -xml -utf8 -quiet',
        safe_path($file),
        '2>&1 | grep -i error | grep -v "errors were found" >',
        safe_path( $err_resource->local_path )
    );

    die "Unable to run command: '", join( ' ', @cmd ), "'"
        unless ( &safe_system(@cmd) );

    if ( -s $err_resource->local_path ) {
        return ( [ $err_resource, status => "cannot tidy up your XML" ] );
    }
    return ();
}


=head2 C<clean_xml>

Clean up strings before parsing.

From L<http://stackoverflow.com/questions/1016910/how-can-i-strip-invalid-xml-characters-from-strings-in-perl>

=cut

sub clean_xml{
    my ($string) = @_;
    &clean_xml_no_copy($string);
    return $string;
}

sub clean_xml_no_copy{
    # allowed: [#x1-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF]
    $_[0] =~ s/[^\x01-\x{D7FF}\x{E000}-\x{FFFD}\x{10000}-\x{10FFFF}]//go;
    # restricted:[#x1-#x8][#xB-#xC][#xE-#x1F][#x7F-#x84][#x86-#x9F]
    $_[0] =~ s/[\x01-\x08\x0B-\x0C\x0E-\x1F\x7F-\x84\x86-\x9F]//go;
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