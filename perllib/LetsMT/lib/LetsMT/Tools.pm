package LetsMT::Tools;

=head1 NAME

LetsMT::Tools - general good-to-have stuff

=head1 DESCRIPTION

=cut

use strict;

use Log::Log4perl qw(get_logger :levels);
use Data::Dumper;

use File::BOM ':all';
use File::Basename;
use File::Find;
use File::ShareDir;

use Encode qw(decode decode_utf8 encode);

use IPC::Open3;
use IPC::Run qw(run start pump finish timeout);


#########################
## TODO: not working yet ....
## from https://metacpan.org/pod/distribution/mod_perl/docs/api/Apache2/SubProcess.pod
# use Apache;
# use Apache2::SubProcess ();
# my $r = shift;
# use Config;
# use constant PERLIO_IS_ENABLED => $Config{useperlio};
#########################


use Symbol qw(gensym);
use LetsMT::Repository::Err;
# use LetsMT::Lang::Encoding;

use Exporter 'import';
our @EXPORT = qw(
    open_bom_file
    fgets
    utf8_to_perl  utf8_to_perl_no_copy
    safe_path  safe_path_utf8
    safe_system
    open_cmd close_cmd run_cmd 
    pipe_out_cmd pipe_out_cmd_quiet
    pipe_in_out_cmd pipe_in_out_cmd_quiet
    cacheopen cacheclose append
);
our %EXPORT_TAGS = ( all => \@EXPORT );


=head1 VARIABLES

=head2 C<$DEFAULT_INPUT_ENCODING>

Relaxed utf-8 encoding, C<utf8>.
Accepts characters that are interpretable utf-8 characters, but strictly incorrect.
Good for reading.

=head2 C<$TIMEOUT>

Timeout for system calls (see run_cmd). Default = 60 seconds.

=cut

our $DEFAULT_INPUT_ENCODING = 'utf8';
our $TIMEOUT = 300;

=head2 C<$DEFAULT_OUTPUT_ENCODING>

Strict utf-8 encoding, C<utf-8>.
Good for writing.

=cut

our $DEFAULT_OUTPUT_ENCODING = 'utf-8';

our @ZCAT  = qw(gzip -cd);
our @BZCAT = qw(bzcat);


=head1 FUNCTIONS

=head2 C<fgets>

 $line = fgets ($fh, $limit)

Read a line with a pre-defined buffer limit.

=cut

# taken from
# http://stackoverflow.com/questions/2930465/in-perl-can-i-limit-the-length-of-a-line-as-i-read-it-in-from-a-file-like-fget
#
# cannot use File::fgets because this ignores PerlIO layers
# 
# but: this implementation is damn slow!
# --> use File::GetLineMaxLength instead!

sub fgets {
    my ($fh, $limit) = @_;

    my ($char, $str);
    for(1..$limit) {
        my $char = getc $fh;
        last unless defined $char;
        $str .= $char;
        last if $char eq "\n";
    }
    return $str;
}


=head2 C<open_bom_file>

 open_bom_file ($file [, $encoding])

Open C<$file> for input.

If C<$encoding> evaluates to C<false>,
the default (C<$DEFAULT_INPUT_ENCODING>) is used.

=cut

sub open_bom_file {
    my $file = shift or get_logger(__PACKAGE__)->error('Invalid filename supplied');
    # my $enc  = shift || get_bom_encoding ($file) || $DEFAULT_INPUT_ENCODING;
    my $enc  = shift || get_bom_encoding ($file);
    my $fh;

    $enc = &LetsMT::Lang::Encoding::detect_encoding($file) unless ($enc);
    $enc = $DEFAULT_INPUT_ENCODING unless ($enc);

    # my $read = _read_mode($file);
    if ( $file =~ /\.gz$/ ) {
        open( $fh, "-|:encoding($enc)", @ZCAT , $file ) or return undef;
    }
    elsif ( $file =~ /\.bz2$/ ) {
        open( $fh, "-|:encoding($enc)", @BZCAT, $file ) or return undef;
    }
    else {
        open( $fh, "<:encoding($enc)"         , $file ) or return undef;
    }

    return wantarray()
        ? ($fh, $enc)
        : $fh;
}


=head2 C<utf8_to_perl>, C<utf8_to_perl_no_copy>

 $new_string = utf8_to_perl ($string);

The C<_no_copy> version performs destructive conversion by changing the original C<$string>.

=cut

sub utf8_to_perl {
    my $string = shift;
    $string = decode_utf8($string);
    return $string;
}

sub utf8_to_perl_no_copy {
    $_[0] = decode_utf8($_[0]);
}

=head2 C<safe_path>, C<safe_path_utf8>

 safe_path (@pathelements);

Clean C<@pathelements> from unsafe '../' and '~' components
that would make it possible to break out of an allowed path.

=cut

sub safe_path{
    my @pathelems = map ( split(/\//), @_ );

    # don't allow moving around in the file system with '..' or '~'
    @pathelems = grep ( $_ !~ /^\.{1,2}$/ , @pathelems );
    $pathelems[0] =~ s/^\~//;

    # escape all special symbols in all path elements
    @pathelems = map ( quotemeta($_), @pathelems );
    return join ('/',@pathelems);
}


sub safe_path_utf8{
    map( $_ = decode('utf8',$_), @_ );
    return &safe_path(@_);
}


# alias on safe_path_utf8
sub safe_utf8_path{
    return &safe_path_utf8(@_);
}


=head2 C<safe_system>

Perform a safe system call.
Any parameters passed to the method are concatenated (joined with space)
to form the command being executed.

Returns C<true> or C<false>.

=cut

## TODO: if we do not join the @cmd to one string: 
##       it fails for commands including utf8 characters ....

sub safe_system {
    my $cmd = join( ' ', @_ );
    get_logger(__PACKAGE__)->debug( Dumper($cmd) );
#    eval { system(@_); };
    eval { system($cmd); };
    if ($@) {
        get_logger(__PACKAGE__)->error( 'system call failed: ' . $@ );
        return 0;
    }
    return 1;
}


=head2 C<open_cmd_>I<X> | C<cmd_>I<X>C<_reader> | C<scrape_cmd_>I<X>

E.g.

 LetsMT::Tools::cmd_out_reader ('gzip -d', 'file.gz');

Execute the given command with possible parameters.
Return either a filehandler (C<open_cmd_X>),
a line iterator (C<cmd_X_reader>)
or a list of output lines (C<scrape_cmd_X>) from the process.

The output is read from either STDOUT (C<X> = C<out>),
STDERR (I<X> = C<err>),
or both (I<X> = C<out_err>).

=cut

sub open_cmd_out {
    my $cmd = join( ' ', @_ );
    if ( open( my $p, "$cmd |" ) ) {
        get_logger(__PACKAGE__)->debug( $cmd );
        return $p;
    }
    else {
        get_logger(__PACKAGE__)->error( 'Failed to execute ' . $cmd );
        return undef;
    }
}


sub open_cmd_out_err {
    my $cmd = join( ' ', @_ );
    if ( open( my $p, "$cmd 2>&1 |" ) ) {
        get_logger(__PACKAGE__)->debug( $cmd );
        return $p;
    }
    else {
        get_logger(__PACKAGE__)->error( 'Failed to execute ' . $cmd );
        return undef;
    }
}


sub open_cmd_err {
    my $cmd = join( ' ', @_ );
    if ( open( my $p, "$cmd 2>&1 >/dev/null |" ) ) {
        get_logger(__PACKAGE__)->debug( $cmd );
        return $p;
    }
    else {
        get_logger(__PACKAGE__)->error( 'Failed to execute ' . $cmd );
        get_logger(__PACKAGE__)->error( 'Returned error: ' . $! );
        return undef;
    }
}


sub cmd_out_reader {
    if ( my $p = &open_cmd_out(@_) ) {
        return sub { return <$p>; }
    }
    else {
        return sub { return undef; }
    }
}


sub cmd_out_err_reader {
    if ( my $p = &open_cmd_out_err(@_) ) {
        return sub { return <$p>; }
    }
    else {
        return sub { return undef; }
    }
}


sub scrape_cmd_out {
    my @lines;
    if ( my $p = &open_cmd_out(@_) ) {
        while (<$p>) {
            chomp;
            push @lines, $_;
        }
        close $p;
    }
    return \@lines;
}


sub scrape_cmd_err {
    my @lines;
    if ( my $p = &open_cmd_err(@_) ) {
        while (<$p>) {
            chomp;
            push @lines, $_;
        }
        close $p;
    }
    return \@lines;
}


sub scrape_cmd_out_err {
    my @lines;
    if ( my $p = &open_cmd_out_err(@_) ) {
        while (<$p>) {
            chomp;
            push @lines, $_;
        }
        close $p;
    }
    return \@lines;
}


# even more sub routines for running external programs ....
#
# !!!! IMPORTANT: IPC::Open3 does not work with mod_perl !!!!!
# ---> we use IPC::Run


# run_cmd via IPC::Run
#
# run_cmd( @cmd_and_args )
# returns ( $succes, $exit_value, $output, $error )
#
# $exit_value = exit value of the command
# $out        = all output to STDOUT in one string
# $err        = all output to STDERR in one string


## TODO: run_cmd cannot be used to pipe output/error to files

sub run_cmd_old {
    my @cmd=@_;
    my ($in,$out,$err);
    # get_logger(__PACKAGE__)->debug( 'run_cmd: ' . join(' ',@cmd) );
    my $success = run \@cmd, \$in, \$out, \$err;
    return wantarray ? ($success ,$? >> 8,$out,$err) : $success;
}


sub run_cmd {
    my @cmd=@_;
    my ($in,$out,$err);

    my ($h, $success);
    eval {
	$h = start \@cmd, \$in, \$out, \$err, timeout( $TIMEOUT );
	$success = finish $h;
    };
    if ( $@ ) {
	print STDERR "killed job: ".join(' ',@cmd)."\n";
	$h->kill_kill if (ref($h));
	# $success = 0;

	## try another type of system call
	## TODO: why not always using this one?
	## TODO: is this safe enough ...?
	my @outlines = scrape_cmd_out(@cmd);
	$success = 1;
	$out = join('',@outlines);
    }
    return wantarray ? ($success ,$? >> 8,$out,$err) : $success;
}


# #############################################
# ## TODO: this does not seem to work ...
# ##
# ## run_cmd via Apache::SubProcess
# sub run_cmd_apache{
#     my $command = shift;
#     my @argv = @_;

#     get_logger(__PACKAGE__)->debug( 'run command in apache ' . $command. ' '.join(' ',@argv) );
#     my $r = new Apache2::SubProcess;
#     my ($in, $out, $err) = $r->spawn_proc_prog($command,\@argv);
#     close($in);
#     my $output = _read_data($out);
#     my $error = _read_data($err);
#     close($out);
#     close($err);
#     my $success = $error ? 1: 0;
#     return wantarray ? ($success ,$? >> 8,$output,$error) : $success;
# }

# # helper function to work w/ and w/o perlio-enabled Perl
# sub _read_data {
#     my ($fh) = @_;
#     my $data;
#     if (PERLIO_IS_ENABLED || IO::Select->new($fh)->can_read(10)) {
# 	my @lines = <$fh>;
# 	$data = join("\n",@lines);
#     }
#     return defined $data ? $data : '';
# }

###############################################################







## TODO: is it wise to have yet another function to allow piping to files?
##       What's about storing stderr in a file?

sub pipe_out_cmd {
    my $out = shift;
    my @cmd=@_;

    my $err;
    my $success = run \@cmd, '<', \undef, '>', $out;
    return wantarray() ? ($success, $? >> 8) : $success;
}

sub pipe_in_out_cmd {
    my $in  = shift;
    my $out = shift;
    my @cmd=@_;

    my $err;
    my $success = run \@cmd, '<', $in, '>', $out;
    return wantarray() ? ($success, $? >> 8) : $success;
}

sub pipe_out_cmd_quiet {
    my $out = shift;
    my @cmd=@_;

    my $err;
    my $success = run \@cmd, '<', \undef, '>', $out, '2>/dev/null';
    return wantarray() ? ($success, $? >> 8) : $success;
}

sub pipe_in_out_cmd_quiet {
    my $in  = shift;
    my $out = shift;
    my @cmd=@_;

    my $err;
    my $success = run \@cmd, '<', $in, '>', $out, '2>/dev/null';
    return wantarray() ? ($success, $? >> 8) : $success;
}

sub open_cmd {
    my @cmd=@_;

    my $in = gensym;
    my $out = gensym;
    my $err = gensym;

    my $cmd_handle = start \@cmd, '<pipe', $in, '>pipe', $out, '2>pipe', $err;
    return ($cmd_handle,$in,$out,$err);
}

sub close_cmd {
    return finish $_[0] if (ref($_[0]));
}




=head2 C<open_out_file>

 $fh = LetsMT::Tools::open_out_file ($file, $encoding)

Open C<$file> for output.

If C<$encoding> is missing or evaluates as C<false>,
the default (C<$DEFAULT_OUTPUT_ENCODING>) is used.

=cut

sub open_out_file {
    my $file     = shift || warn "Invalid filename supplied";
    my $encoding = shift || $DEFAULT_OUTPUT_ENCODING;
    open( my $fh, ">:encoding($encoding)", $file )
        || get_logger(__PACKAGE__)->error( 'Failed to open ' . $file );
    return $fh;
}


=head2 C<open_in_file>

An alias for C<open_bom_file>.

=cut

sub open_in_file {

    ## simple: just use open_bom_file
    return &open_bom_file(@_);

## without open_bom

    # my $file = shift
    #     || get_logger(__PACKAGE__)->error('Invalid filename supplied');
    # my $enc = shift || $DEFAULT_INPUT_ENCODING;
    # my $read = _read_mode($file);
    # open( my $fh, $read, ":encoding($enc)" );
    # return $fh;

## old style (without support for zipped files)

    # my $file     = shift || warn "Invalid filename supplied";
    # my $encoding = shift || $DEFAULT_INPUT_ENCODING;
    # open( my $fh, "<:encoding($encoding)", $file )
    #     || get_logger(__PACKAGE__)->error( 'Failed to open ' . $file );
    # return $fh;
}


=head2 C<get_bom_encoding>

 LetsMT::Tools::get_bom_encoding ($file)

Try to determine the encoding of C<$file> by examining the BOM.

=cut

sub get_bom_encoding {
    my ($file) = shift or get_logger(__PACKAGE__)->error('Invalid filename supplied');
    my $fh;

    if ( $file =~ /\.gz$/ ) {
        open( $fh, "-|:bytes", @ZCAT , $file ) or return undef;
    } elsif ( $file =~ /\.bz2$/ ) {
        open( $fh, "-|:bytes", @BZCAT, $file ) or return undef;
    } else {
        open( $fh, "<:bytes"         , $file ) or return undef;
    }

    (my $encoding) = File::BOM::get_encoding_from_stream ($fh);
    close($fh);
    return $encoding;
}


=head2 C<q_string>, C<qq_string>

 LetsMT::Tools::q_string  ($string)
 LetsMT::Tools::qq_string ($string)

Add single (C<q_string>) or double (C<qq_string>) quotes around C<$string>.

=cut

sub qq_string { $_[0]=~s/\"/\\\"/gs; return '"' . $_[0] . '"'; }
sub q_string  { $_[0]=~s/\'/\\\'/gs; return '\'' . $_[0] . '\''; }


sub mkdir{
    my $dir = shift;
    my @subdirs = split(/\/+/,$dir);
    my $thisdir = shift(@subdirs);
    while (@subdirs){
        mkdir $thisdir unless (-e $thisdir);
        $thisdir .= '/'.shift(@subdirs);
    }
    mkdir $thisdir unless (-e $thisdir);
}


=head2 C<xmlify> | C<xmlify_no_copy> | C<xmlify_with_quotes> | C<xmlify_with_quotes_no_copy>

 $string = LetsMT::Tools::xmlify ($string)
 $string = LetsMT::Tools::xmlify_with_quotes ($string)
 LetsMT::Tools::xmlify_no_copy ($string)
 LetsMT::Tools::xmlify_with_quotes_no_copy ($string)

Convert a limited set of characters to xml entities.
The C<_no_copy> versions perform destructive conversion by changing the original C<$string>.
We do not need C<HTML::Entities> or C<XML::Entities>,
since only the characters reserved for XML needs to be fixed.

=cut

sub xmlify {
    my ($string) = @_;
    &xmlify_no_copy($string);
    return $string;
}


sub xmlify_no_copy {
    $_[0] =~ s/\&/&amp;/gs;
    $_[0] =~ s/\</&lt;/gs;
    $_[0] =~ s/\>/&gt;/gs;
#    $_[0] =~ s/\"/&quot;/gs;
#    $_[0] =~ s/\'/&apos;/gs;
}


sub xmlify_with_quotes {
    my ($string) = @_;
    &xmlify_with_quotes_no_copy($string);
    return $string;
}


sub xmlify_with_quotes_no_copy {
    $_[0] =~ s/\&/&amp;/gs;
    $_[0] =~ s/\</&lt;/gs;
    $_[0] =~ s/\>/&gt;/gs;
    $_[0] =~ s/\"/&quot;/gs;
    $_[0] =~ s/\'/&apos;/gs;
}


=head2 C<build_lookup_func>

 LetsMT::Tools::build_lookup_func ($map, $prefix, $suffix)

Build a lookup function that searches the first parameter for any matches to
prefix key suffix, and replces them with the key's value.

=cut

sub build_lookup_func {
    my ( $map, $prefix, $suffix ) = @_;
    my %map = %$map;
    $prefix = '' unless ( defined $prefix );
    $suffix = '' unless ( defined $suffix );
    my $regex = $prefix . '(' . join( '|', keys %map ) . ')' . $suffix;
    return sub {
        if ( $_[0] =~ /$regex/is ) {
            return $map{$1};
        }
        else {
            return undef;
        }
    };
}


=head2 C<find_files>

 LetsMT::Tools::find_files ($pattern, $location)

Recursively find all files in C<$location> matching C<$pattern>.

=cut

sub find_files {
    my $pattern = shift;
    return () if (not @_);
    my @files = ();
    find( sub{
        push( @files, $File::Find::name ) if (/$pattern/)
    }, @_ );
    return @files;
}


=head2 C<find_files_relative>

 LetsMT::Tools::find_files_relative ($pattern, $location)

Recursively find all files in C<$location> matching C<$pattern>,
returning their paths relative to C<$location>.

=cut

sub find_files_relative {
    my $pattern = shift;
    my $dir = shift || return ();
    my @files = &find_files($pattern, $dir);
    return map { $_ = substr($_, length($dir)+1) } @files;
}


=head2 C<unescape>

Does the same as URI::Escape::uri_unescape with the addition of converting '+' to ' '.
This is need as URI::query_form encodes spaces in URIs to '+' and not to a %-encoding.

=cut

sub unescape {
    my $string = shift;

    $string =~ s/\+/ /g;
    $string =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;

    return $string;
}



=head2 C<cacheopen>, C<append>, C<cacheclose>

 my $fh = cacheopen $file;
 my $fh = cacheopen $file, $encoding;

 $fh = cacheopen $file;
 print $fh "something";
 # ...
 $fh = cacheopen $file;
 print $fh "something more";
 cacheclose $file;
 
 # or:
 # ...
 append $file, "something else";

Cached (write-only) file-handle management (inspired by core module FileCache).

Be sure to call C<cacheopen> each time before you try to write to a file
after you may have written to some other file; or use C<append>.

The maximum number of open files is 100 by default.
You can change it via the variable C<$LetsMT::Tools::MAX_OPEN_FILES>.

The default encoding is utf8.

=cut

our $MAX_OPEN_FILES = 100;
my  %FILE_OPEN_COUNT = ();
my  %FILE_ENCODINGS = ();
my  %OPEN_FILES = ();

sub cacheopen {
    my $file = shift;

    ## If $file is already open, there is nothing to do...
    unless ( defined $OPEN_FILES{$file} ) {
        ## use correct encoding
        $FILE_ENCODINGS{$file} = shift || $FILE_ENCODINGS{$file} || 'utf8';

        while ( scalar keys %OPEN_FILES >= $MAX_OPEN_FILES ) {
            my @list = sort { $FILE_OPEN_COUNT{$b} <=> $FILE_OPEN_COUNT{$a} }
                keys %OPEN_FILES;
            #print STDERR "closing $list[0]\n";
            &cacheclose( $list[0] );
        }

        if ($FILE_OPEN_COUNT{$file}) {
            #print STDERR "re-open $file\n";
            open $OPEN_FILES{$file}, ">>:encoding($FILE_ENCODINGS{$file})", $file
                or die "cannot write to $file\n";
        }
        else{
            #print STDERR "open $file\n";
            open $OPEN_FILES{$file}, ">:encoding($FILE_ENCODINGS{$file})", $file
                or die "cannot write to $file\n";
        }
    }

    ## Register how often $file has been opened.
    $FILE_OPEN_COUNT{$file}++;
    return $OPEN_FILES{$file};
}


sub append {
    my $file = shift;
    my $fh   = &cacheopen( $file );
    print $fh @_;
    return $file;
}


sub cacheclose {
    my $file = shift;
    if ( defined $OPEN_FILES{$file} ) {
        close $OPEN_FILES{$file} || die "cannot close $file\n";
        delete $OPEN_FILES{$file};
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
