#!/usr/bin/perl
#-*-perl-*-
package Scaffold;

=head1 NAME

Scaffold - auxiliary

=cut

use strict;
use warnings;

use Exporter 'import';
our @EXPORT = qw(
    add_user del_user pop_user
    create_users clear_all_users
    xml_to_dom  xml_to_hash
    http_to_dom http_to_hash
    success_hash
    tempdir
);

use sigtrap handler => \&cleanup, 'normal-signals';

use open qw(:std :locale);
use Encode;
use Encode::Locale;
Encode::Locale::decode_argv;

use LetsMT::WebService;

use Test::More;
my $builder = Test::More->builder;
binmode $builder->output,         ":utf8";
binmode $builder->failure_output, ":utf8";
binmode $builder->todo_output,    ":utf8";

use Data::Dumper;
use XML::LibXML;
my $XMLParser = new XML::LibXML;

our @groups = ();
our @users  = ();


=head1 SIGNAL-HANDLER FUNCTION

=head2 C<cleanup>

This function is set as the handler for all normal interrupt signals,
but can/should also be called explicitly at the end of the script.
If triggered by a signal (= called with an argument), it dies in the end.

You can redefine it in your script and call Scaffold::cleanup
on the last line of the new function.

=cut

sub cleanup
{
    #print "cleaning up\n";
    my $SIGNAME = shift;
    &clear_all_users;
    die "Cleaned up after signal $SIGNAME\n" if defined $SIGNAME;
}


=head1 FUNCTIONS - User management

=head2 C<add_user>

 my ($uid, $gid) = add_user

Create a user/group pair.

=cut

sub add_user
{
    my $id   = int( rand(999999999999) );
    my $gid  = 'group_id_' . $id;
    my $uid  = 'user_id_'  . $id;

    LetsMT::WebService::post_group( $gid, undef, $uid );

    push (@groups, $gid);
    push (@users , $uid);
    return ($uid, $gid);
}


=head2 C<create_users>

Create a given number of user/group pairs.

=cut

sub create_users
{
    my $count = shift or return 0;
    while ($count) {
        add_user;
        $count--;
    }
}


=head2 C<del_user>

 del_user($uid, $gid)

=cut

sub del_user
{
    my $uid = shift;
    my $gid = shift;

    # Remove group $gid
    LetsMT::WebService::del_group( $gid, undef, $uid );
    # Remove group $uid
    LetsMT::WebService::del_group( $uid, undef, $uid );
    # Remove $uid from group 'public'
    LetsMT::WebService::del_group( 'public', $uid, 'admin' );
}


=head2 C<pop_user>

=cut

sub pop_user
{
    my $gid = pop(@groups);
    my $uid = pop(@users );
    #print "  $uid:$gid\n";
    &del_user($uid, $gid);
}


=head2 C<clear_all_users>

=cut

sub clear_all_users
{
    while (scalar @users) {
        &pop_user;
    }
}


=head1 FUNCTIONS - Webservice response handling

=head2 C<xml_to_dom>

Convert XML content to a DOM object.

=cut

sub xml_to_dom
{
    return $XMLParser->parse_string( shift );
}


=head2 C<xml_to_hash>

Convert the status attributes to a hash for comparison.

=cut

sub xml_to_hash
{
    my $dom      = &xml_to_dom(shift);
    my $with_msg = shift || 0;

    my $hash = {
        type      => $dom->findnodes('//status/@type'     )->to_literal,
        code      => $dom->findnodes('//status/@code'     )->to_literal,
        operation => $dom->findnodes('//status/@operation')->to_literal,
        location  => $dom->findnodes('//status/@location' )->to_literal,
    };
    $hash->{message} = $dom->findnodes('//status/text()'  )->to_literal
        if $with_msg;

    return $hash;
}


=head2 C<http_to_dom>

=cut

sub http_to_dom
{
    my $http_obj = shift;
    return &xml_to_dom( $http_obj->decoded_content, @_ );
}


=head2 C<http_to_hash>

=cut

sub http_to_hash
{
    my $http_obj = shift;
    return &xml_to_hash( $http_obj->decoded_content, @_ );
}


=head2 C<success_hash>

Prepare a status hash
Convert the status attributes to a hash for comparison.

=cut

sub success_hash
{
    my $location  = shift;
    my $operation = shift || 'GET';
    my $message   = shift;
    my $hash = {
        type      => 'ok',
        code      => 0,
        operation => $operation,
        location  => $location,
    };
    $hash->{message} = $message
        if defined $message;

    return $hash;
}


=head1 FUNCTIONS - Dir/File handling

=head2 C<tempdir>

=cut

sub tempdir
{
    return File::Temp::tempdir(
        'letsmt_testsuite__XXXXXX',
        DIR     => $ENV{TMP} || '/tmp',
        CLEANUP => 1
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