package LetsMT::WWW::ModPerlHandler;

=head1 NAME

LetsMT::WWW::ModperlHandler - Apache2 mod_perl handler

=head1 SYNOPSIS

By having the following location in the apache virtual host file, the mod_perl
handler gets called for every web service HTTP request.

 <Location /ws>
    SetHandler perl-script
    PerlOptions +ParseHeaders
    PerlResponseHandler LetsMT::WWW::ModPerlHandler
 </Location>

=head1 DESCRIPTION

This is the Apache response handler for the web service API of the LetsMT!
resource repository.

=cut

use strict;
use warnings;

use Log::Log4perl qw(get_logger :levels);
use Data::Dumper;
use Scalar::Util qw(blessed);

use Apache2::RequestRec ();
use Apache2::RequestIO  ();
use Apache2::RequestUtil ();
use Apache2::Const -compile => qw(OK DONE);

use LetsMT::Repository::API;


=head1 CLASS METHOD

=head2 Request Handler C<handler>

This is the hook called by Apache's mod_perl, the entry point.

Parameter: C<$mod_perl_env>

Returns: an C<Apache2::Const::DONE> or C<::OK> constant.

Throws no exception.

=cut

sub handler {
    my $r      = shift;
    my $logger = get_logger(__PACKAGE__);

    # Create API object via factory method
    my $api_result = new LetsMT::Repository::API($r);

    # Add a cleanup handler
    $r->push_handlers( PerlCleanupHandler => \&cleanup );

    # If $api_object is a proper object
    if ( blessed ($api_result) && $api_result->isa('LetsMT::Repository::API') ) {
        my $result     = undef;
        my $errcode    = undef;
        my $errmsg     = undef;
        my $package    = undef;
        my $filename   = undef;
        my $line       = undef;
        my $httpstatus = undef;

        # Execute the requested method in process()
        eval { $result = $api_result->process(); };

        if ($@) {
            if ( $@->isa('LetsMT::WWW::LetsMT_modperl_handler_exception::Exception')
            ) {
                ( $errcode, $errmsg, $httpstatus, $package, $filename, $line ) = (
                    $@->{code}, $@->{msg}, $@->{http}, $@->{package},
                    $@->{filename}, $@->{line}
                );
            }
            elsif ( ref($@) eq "" ) {
                ( $errcode, $errmsg, $httpstatus ) = ( 8, $@, 500 );
            }
            else {
                ( $errcode, $errmsg, $httpstatus ) = ( 8, "system error", 500 );
            }
        }

        # If $result is not empty...
        if ( ref($result) && $$result ) {
            # If result is a file -> download file
            if ( $$result !~ m/^</ && -f $$result ) {
                $r->content_type("application/x-download");

                open( SOURCE, "<", $$result )
                    or die "Couldn't open '$$result' for reading: $!\n";
                &_copy_file( \*SOURCE, \*STDOUT );
                close(SOURCE) or die "Couldn't close $$result$!\n";

                # remove temporary download file
                unlink($$result);
            }
            else {   # ...otherwise return value should be a XML result string
                     # Print result and return OK
                $r->content_type('text/xml; charset=utf-8');
                $r->status(200); #TODO: set proper HTTP response code here, $$result->{status}
                $r->print( $$result . "\n" );
            }

            $result = undef;
            $api_result = undef;
            return Apache2::Const::OK;
        }
        else {        # Result was emtpy
                      # Prepare Result object with error message
            my $result_obj = new LetsMT::Repository::Result(
                type      => 'error',
                operation => $r->method,
                location  => $r->path_info,
                message   => $errmsg || 'System level failure: Got empty result',
                code      => $errcode || '8',
            );

            $logger->warn( 'method: '
                    . $r->method
                    . ', code: '
                    . ( $errcode || '8' )
                    . ', location: '
                    . $r->path_info
                    . ', message: '
                    . ( $errmsg || 'System level failure: Got empty result' )
            );

            $r->content_type('text/xml; charset=utf-8');
            $r->status(500);
            $r->print( ${ $result_obj->get_xml_result() } );

            $result_obj = undef;
            $api_result = undef;
            return Apache2::Const::DONE;
        }
    }
    else
    {   #got no propper $api_object, report that via XML Result string as well
        my $result_obj = new LetsMT::Repository::Result(
            type      => 'error',
            operation => $r->method,
            location  => $r->path_info,
            message   => $api_result->{'message'},
            code      => $api_result->{'code'},
        );

        $r->content_type('text/xml; charset=utf-8');
        $r->status(400);
        $r->print( ${ $result_obj->get_xml_result() } );

        $result_obj = undef;
        $api_result = undef;
        return Apache2::Const::DONE;
    }

    # Something else went wrong
    $api_result = undef;
    return Apache2::Const::DONE;
}


=head2 Cleanup Handler C<cleanup>

Cleaning up temporary files.

=cut

## TODO: do we need more cleanup than this?

sub cleanup{
    File::Temp::cleanup();
}


=head1 INTERNAL UTILITY METHOD

=head2 C<_copy_file>

 &_copy_file($source, $dest);

A general file stream copy that will not mess up binary files.

Returns: true on success, false on failure.

Parameters: filehandles for source and destination.

=cut

sub _copy_file {
    my ( $sfh, $tfh ) = @_;
    my $buffer;

    binmode($sfh);
    binmode($tfh);

    while ( read( $sfh, $buffer, 65536 ) and print $tfh $buffer ) { }

    return 0 if $!;

    return 1;
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