package LetsMT::Repository::StorageManager;

=head1 NAME

LetsMT::Repository::StorageManager - storage manager

=head1 DESCRIPTION

This is the storage manager API.

=cut

use strict;
use parent 'XML::Simple';

use open qw(:std :utf8);

use LetsMT::Repository::GroupManager;
use LetsMT::Repository::Storage;
use LetsMT::Repository::StorageManager::Partition;
use LetsMT::Repository::StorageManager::Slot;
use LetsMT::Repository::StorageManager::Branch;
use LetsMT::Repository::MetaManager;

use LetsMT::Tools;
use LetsMT::Repository::Err;

use Log::Log4perl qw(get_logger :levels);
use Data::Dumper;


=head1 FUNCTIONS

=head2 C<drop_tables>

Clean out the database.
Use with care...

Returns: nothing

=cut

sub drop_tables {
    LetsMT::Repository::StorageManager::Partition::drop_table();
    LetsMT::Repository::StorageManager::Branch::drop_table();
    LetsMT::Repository::StorageManager::Slot::drop_table();
}


=head2 C<create_storage>

 $status = &LetsMT::Repository::StorageManager::create_storage (
     path       => $path,
     uid        => $uid,
     gid        => $gid,
     userread   => $userread,
     userwrite  => $userwrite,
     groupread  => $groupread,
     groupwrite => $groupwrite,
     otherread  => $otherread,
     otherwrite => $otherwrite,
     payload    => $payload
 )

Create data, either only a slot and a branch, or a file with contents in a branch's directory.
The other arguments are metadata for the branch.

If C<$path> only consists of [slot, branch], then only that is created.

If C<$path> contains more, it must have a FILE (not directory) last, in which to deliver the payload.

Returns: an XML-formatted string indicating the status.

=cut

sub create_storage {
    my %args    = @_;
    my $message = $args{message};
    my $pathref = $args{path} or raise( 12, "parameter path", 'warn' );
    $pathref = [ @{$pathref} ];    #make copy so we can modify it

    my $uid = $args{uid} or raise( 12, "parameter uid", 'warn' );
    my $payload = $args{payload};

    my $slot       = shift( @{$pathref} );
    my $branch     = shift( @{$pathref} );
    my $targetfile = $payload
        ? pop( @{$pathref} ) || ""
        : "";  #if there is a payload file, pathref gets the *directory* part pointing to it

    my $logger     = get_logger(__PACKAGE__);

    ### safe action performed to return a useful message
    my $did_action = "";

    ### Check params and conflicts
    raise( 12, "slot parameter", 'warn' )  unless ( defined($slot) );

    ### Find/create slot
    my $slotobj = &_get_slot( name => $slot );

    ### slot not found --> try to create
    unless ($slotobj) {
        $slotobj = &create_storage_slot( $slot, $uid, $args{type} );
        unless ( defined($branch) ) {
            $$message = "Created slot '$slot'";
            return 1;
        }
    }
    elsif ( not defined $branch ) {
        raise( 4, $slot, 'warn' );    # Slot exists already
    }

    #### Find/create branch
    my $branchobj;
    $branchobj = &_get_branch(
        name => $branch,
        user => $uid,
        slot => $slot
    ) or do {
        $branchobj = &create_storage_branch( $slotobj, $branch, %args );
        $did_action .= "Created branch $branch ";
    };

    #### We're done unless there's also a targetfile or targetdir involved or some more dirs need to be created
    unless (
        ( defined($targetfile) && length $targetfile )
        || scalar @{$pathref}
    ) {
        $$message = $did_action;
        return 1;
    };

    #### Check for create conflict
    raise( 14, "$uid has no write permission on $slot/$branch", 'warn' )
        unless ( $branchobj->may_write(
            $uid,
            &LetsMT::Repository::GroupManager::get_groups_for_user($uid)
        ) );

    my $vc = new LetsMT::Repository::Storage(
        $slotobj->type
    ) or raise( 9, "Storage Backend", 'error' );

    #### Create directory if pathref is set and it does not point to a dir that already exists
    if (
        ( scalar @{$pathref} > 0 )
        && ! $vc->is_path(
            repos  => $slot,
            branch => $branch,
            dir    => join( '/', @{$pathref} ),
            user   => $uid,
        )
    ) {
        $vc->mkdir( $slot, $branch, $uid, join( '/', @{$pathref} ) );
        $did_action .= "mkdir ";
    }

    #### Store file (create or update)
    if ( defined($targetfile) && $targetfile ) {
        ## If file exists, update, otherwise add
        if ( $vc->is_path(
                repos  => $slot,
                branch => $branch,
                dir    => join( '/', @{$pathref} ),
                file   => $targetfile,
                user   => $uid,
            )
        ) {
            $vc->update(
                $uid, $slot, $branch,
                join( '/', @{$pathref} ),
                $targetfile, $payload
            );
            $did_action .= "update ";
        }
        else {
            $vc->add(
                $uid, $slot, $branch,
                join( '/', @{$pathref} ),
                $targetfile, $payload
            );
            $did_action .= "add ";
        }
    }

    $$message = "${did_action}ok /$slot/$branch/"
        . join( '/', @{$pathref}, $targetfile );
    return 1;
}


=head2 C<create_storage_slot>

=cut

sub create_storage_slot {
    my ( $slot, $uid, $type ) = @_;

    my $logger = get_logger(__PACKAGE__);

    raise(17, " backend '$type'") unless (
        exists $LetsMT::Repository::Storage::BACKENDS{$type}
        || ! $type
    );

    my $slotobj = new LetsMT::Repository::StorageManager::Slot(
        $slot, undef, $type
    );

    my $vc = new LetsMT::Repository::Storage(
        $slotobj->type
    ) or raise( 9, "Storage Backend", 'error' );
    $vc->init( $slot, $uid );

    #write meta data for new slot
    my $metaDB = new LetsMT::Repository::MetaManager();
    $metaDB->open();
    my %slot_meta_hash = (
        'creator'       => $uid,               # TODO: can we remove creator
        'owner'         => $uid,               # (same info as creator ...)
        'resource-type' => 'slot',
        'server-url'    => $ENV{LETSMT_URL},
    );
    if ( $metaDB->post( $slot, \%slot_meta_hash ) ) {
        $logger->debug(
            "wrote meta data for $slot",
            Dumper(%slot_meta_hash)
        ) if ( $logger->is_debug );
    }
    else {
        $logger->error("could not write meta data for $slot/$uid");
    }
    $metaDB->close();
    return $slotobj;
}


=head2 C<create_storage_branch>

=cut

sub create_storage_branch {
    my ( $slotobj, $branch, %args ) = @_;

    raise( 12, "parameter uid", 'warn' ) unless defined $args{uid};
    my $uid = $args{uid};
    my $gid = defined $args{gid} ? $args{gid} : 'public';

    my $userread   = $args{userread}   || 1;
    my $userwrite  = $args{userwrite}  || 1;
    my $groupread  = $args{groupread}  || 1;
    my $groupwrite = $args{groupwrite} || 0;
    my $otherread  = $args{otherread}  || 0;
    my $otherwrite = $args{otherwrite} || 0;

    my $logger     = get_logger(__PACKAGE__);
    my $did_action = "";

    ## A new branch must belong to a group
    my $grpobj = LetsMT::Repository::GroupManager::group_exists($gid);
    raise( 3, $gid, 'warn' ) unless ($grpobj);

    # TODO: do we need diskname here? (see also the Branch object constructor)
    my $slot     = $slotobj->name;
    my $diskname = $slotobj->diskname;

    my $vc = new LetsMT::Repository::Storage(
        $slotobj->type
    ) or raise( 9, "Storage Backend", 'error' );

    $logger->debug( "mkdir $slot/$branch ($uid)");
    $vc->mkdir( $slot, $branch, $uid, '' );
    my $branchobj = new LetsMT::Repository::StorageManager::Branch(
        $diskname,   $branch,    $slot,      $uid,
        $gid,        $userread,  $userwrite, $groupread,
        $groupwrite, $otherread, $otherwrite
    );

    ## Write meta data for new branch
    my $metaDB = new LetsMT::Repository::MetaManager();
    $metaDB->open();
    my %branch_meta_hash = (
        'uid'           => $uid,
        'resource-type' => 'branch',
        'gid'           => $gid,
    );
    if ( $metaDB->post( $slot . "/" . $branch, \%branch_meta_hash ) ) {
        $logger->debug( "wrote meta data for $slot/$uid",
            Dumper(%branch_meta_hash)
        ) if ( $logger->is_debug );
    }
    else {
        $logger->error("could not write meta data for $slot/$uid");
    }
    $metaDB->close();
    return $branchobj;
}


=head2 C<copy_branch>

 &LetsMT::Repository::StorageManager::copy_branch (
     path       => $path,
     uid        => $uid,
     gid        => $gid,
     userread   => $userread,
     userwrite  => $userwrite,
     groupread  => $groupread,
     groupwrite => $groupwrite,
     otherread  => $otherread,
     otherwrite => $otherwrite,
     dest       => $dest,
 )

Copy a branch to a new destination.
Must be in the same slot.
The metadata arguments are used for the new branch.

FIXME: should return an XML-formatted string indicating success (presently, 
this bug is caught in the mod_perl handler and assigned something standard).

Returns: true (an exception is raised on failure).

=cut

sub copy_branch {
    my %args        = @_;
    my $message_ref = $args{message};
    my $pathref     = $args{path}
        or raise( 12, "parameter path in copy_branch", 'warn' );
    $pathref = [ @{$pathref} ];    #make copy so we can modify it
    my $uid = $args{uid}
        or raise( 12, "parameter uid in copy_branch", 'warn' );
    my $gid        = $args{gid};
    my $userread   = $args{userread} || 1;
    my $userwrite  = $args{userwrite} || 1;
    my $groupread  = $args{groupread} || 1;
    my $groupwrite = $args{groupwrite} || 0;
    my $otherread  = $args{otherread} || 0;
    my $otherwrite = $args{otherwrite} || 0;
    my $dest       = $args{dest};              ## a simple branchname

    my $slot   = shift( @{$pathref} );
    my $branch = shift( @{$pathref} );

    ### Check params and conflicts
    raise( 12, "slot parameter",   'warn' ) unless ( defined($slot) );
    raise( 12, "branch parameter", 'warn' ) unless ( defined($branch) );
    my $slotobj   = &_get_slot(
        name => $slot
    ) or raise( 6, "slot $slot", 'warn' );
    my $branchobj = &_get_branch(
        name => $branch,
        user => $uid,
        slot => $slot,
    ) or raise( 6, "branch $branch", 'warn' );

    $gid = $gid ? $gid : $branchobj->grp;

    #### Find/create branch
    my $trgbranchobj = &_get_branch( name => $dest, user => $uid, slot => $slot );
    raise( 4, "target branch $dest", 'warn' ) if ($trgbranchobj);

    # get_logger(__PACKAGE__)->debug("......... copy branch to $dest($uid)");

    ## A new branch must belong to a group
    my $grpobj = LetsMT::Repository::GroupManager::get_group( $gid )
        or raise( 3, $gid, 'warn' );

    my $vc = new LetsMT::Repository::Storage(
        $slotobj->type
    ) or raise( 9, "Storage Backend", 'error' );

    $vc->copy( $uid, $slot, $branch, $dest );

    $branchobj = new LetsMT::Repository::StorageManager::Branch(
        $slotobj->diskname, $dest,      $slot,      $uid,
        $gid,               $userread,  $userwrite, $groupread,
        $groupwrite,        $otherread, $otherwrite
    ) or raise( 6, "slot $dest after creation", 'warn' );
    # Can not find/read...

    # Update metadata of new branch
    # name, create?, modify?
    my $metaDB = new LetsMT::Repository::MetaManager();
    $metaDB->open();
    my %branch_meta_hash = ( 'name' => $dest, );

    get_logger(__PACKAGE__)->error(
        "could not write meta data for $slot/$dest", 'error'
    ) unless ( $metaDB->post( $slot . '/' . $dest, \%branch_meta_hash ) );
    $metaDB->close();

    $$message_ref = "copied branch '$slot/$branch' to '$dest'";
    return 1;
}


=head2 C<list_storage>

 $listing = &LetsMT::Repository::StorageManager::list_storage ($result_ref, $pathref, $user, $rev)

List storage.

Returns: an XML-formatted string with a content listing.

=cut

sub list_storage {
    my ( $result_ref, $pathref, $uid, $rev ) = @_;

    $pathref = [ @{$pathref} ];    #make copy so we can modify it
    my $slot = shift( @{$pathref} );

    # Check if uid is set
    raise( 12, 'uid', 'warn' ) unless ($uid);

    # If no slot name given, list all slots
    unless ($slot) {
        $$result_ref = &list_storage_slots( $uid );
        return 1;
    }

    # If slot name is given, check if it exists
    my $slotobj = &_get_slot(
        name => $slot
    ) or raise( 6, "slot '$slot'", 'warn' );

    # If a branch name was given, list that branch or contained resources
    if ( scalar( @{$pathref} ) ) {
        my $branch = shift( @{$pathref} );
        $$result_ref = &list_storage_branch_filelist(
            $slotobj, $slot, $branch, $uid, $pathref, $rev
        );
        return 1;
    }

    # No branch name given, list the user branch in the slot
    $$result_ref = &list_storage_branches( $slot, $uid );

    return 1;
}


=head2 C<cat_storage>

 $data = &LetsMT::Repository::StorageManager::cat_storage ($result_ref, $pathref, $user, $range, $rev)

Read out storage.

Returns: file contents (?)

=cut

sub cat_storage {
    my ( $result_ref, $pathref, $uid, $range, $rev ) = @_;
    my $path_string = join( '/', @$pathref );

    raise( 6, "path " . $path_string, 'warn' )  unless (
        &LetsMT::Repository::StorageManager::existent(
             path => $pathref,
             rev  => $rev,
             uid  => $uid
        )
    );

    my $slot = $$pathref[0];
    my $slotobj = &_get_slot(
        name => $slot
    ) or raise( 6, "slot $slot", 'warn' );

    my $vc = new LetsMT::Repository::Storage(
        $slotobj->type 
    ) or raise( 9, "Storage Backend", 'error' );

    my $file_content = $vc->cat( $range, $pathref, $uid, $rev );

    # If pathref points to a file
    my $result = {
        'path'  => '/' . $path_string,
        'entry' => [$file_content],
    };

    $$result_ref = $result;
    return 1;
}


=head2 C<list_storage_branch_filelist>

 list_storage_branch_filelist ($slotobj, $slot, $branch, $user, $pathref, $rev)

A helper function for C<list_storage>, don't use directly.

Returns: an XML-formatted listing string.

=cut

sub list_storage_branch_filelist {
    my ( $slotobj, $slot, $branch, $user, $pathref, $rev ) = @_;

    $pathref = [ @{$pathref} ];    #make copy so we can modify it
    my $branchobj = undef;

    my $vc = new LetsMT::Repository::Storage(
        $slotobj->type
    ) or raise( 9, "Storage Backend", 'error' );

    my $entries  = [];
    my $tmp_path = undef;

    # Get the branch if user has access to it
    $branchobj = &_get_branch(
        user => $user,
        slot => $slot,
        name => $branch
    ) or raise(
        6,
        "branch $branch (either doesn't exist, or you may not access it)",
        'warn'
    );

    do {
        my $branchlist = $vc->list(
            repos  => $slot,
            user   => $user,
            slot   => $slotobj,
            branch => $branchobj,
            dir    => join( '/', $branchobj->name, @{$pathref} ),
            rev    => $rev,
        );

        my $xmlParser = XML::Simple->new;
        my $xml = $xmlParser->XMLin( $branchlist, ForceArray => 1 );

        # build path
        $tmp_path = '/' . join( '/', $slot, $branch, @$pathref );

        # Reduce depth of data structure and get rid of the path element
        $xml = $xml->{'entry'};

        foreach my $entry (@$xml) {
            # Set additional properties if there where any commits listed
            if ( $branchlist =~ /commit/ ) {
                #$entry->{'perm'}  = [ ($branchlist =~ /^.*?kind="file"/s ? "-" : "d") . $branchobj->pp_perms() ];
                $entry->{'owner'} = [ $branchobj->owner ];
                $entry->{'group'} = [ $branchobj->grp ];
            }

            # Add data structure to entries list
            push( @$entries, $entry );
        }
    } while ( $branchobj->restore_next() );

    my $result = {
        'path'       => $tmp_path,
        'entry'      => $entries,
    };

    ## show existing revisions (if $rev is set)
    if ($rev){
        my %revisions = $vc->revisions( $slot, $branch, @{$pathref} );
        foreach (sort { $a <=> $b } keys %revisions){
            push( @{$$result{history}}, {
                    revision => $_,
                    content  => $revisions{$_}
                }
            );
        }
    }

    return $result;
}


=head2 C<_filelist>

 _filelist ($slotobj, $branchobj, $pathref)

An internal helper function for C<list_storage>, don't use directly.

Returns: a list of XML listings

=cut

sub _filelist {
    my ( $slotobj, $branchobj, $pathref ) = @_;

    my $vc = new LetsMT::Repository::Storage(
        $slotobj->type
    ) or raise( 9, "Storage Backend", 'error' );

    my @list = ();
    ### list contents of a branch
    do {
        push(
            @list,
            $vc->list(
                repos  => $slotobj->name,
                slot   => $slotobj,
                branch => $branchobj,
                dir    => join( '/', $branchobj->name, @{$pathref} )
            )
        );
    } while ( $branchobj->restore_next() );
    return @list;
}


=head2 C<list_storage_branches>

 list_storage_branches ($slot, $user)

List branches (that we may see, i.e., that we have read perms on).
TODO: Find out if a user should see other user's slot content via storage GET.

A helper function for C<list_storage>, don't use directly.

Returns: a hash ref containing path and entry with result

=cut

sub list_storage_branches {
    my ( $slot, $user ) = @_;

    my $branchobj = &_get_branch(
        user => $user,
        slot => $slot,
        superuser_view => 0,
    ) or raise( 6, "branche(s) '$slot/$user'", 'warn' );

    my $entries = [];
    do {
        push(
            @$entries,
            {   'kind'  => 'branch',
                'path'  => '/' . $slot . '/' . $branchobj->name,
                'name'  => [ $branchobj->name ],
                'owner' => [ $branchobj->owner ],
                'group' => [ $branchobj->grp ],
            }
        );
    } while ( $branchobj->restore_next() );

    # Build hash ref for result
    my $result = {
        'path'  => "/$slot",
        'entry' => $entries,
    };

    return $result;
}


=head2 C<list_storage_slots>

List all the slots.

Returns: an XML-formatted listing string with slots.

=cut

sub list_storage_slots {
    my $user    = shift || 'admin';  ## is it wise to have admin as default?
    my @slots   = ();

    ## for user 'admin': get all slots in the DB
    if ( $user eq 'admin' ){
	my $slotobj = &_get_slot();    ## no qualifier = all slots
	if ($slotobj) {
	    do { push( @slots, $slotobj->name ) }
            while ( $slotobj->restore_next() );
	}
    }

    ## for regular users: get all readable branches
    ## and store the slots that have at least one of them
    else{
	my $groups = &LetsMT::Repository::GroupManager::get_groups_for_user($user);
	my $metaDB = new LetsMT::Repository::MetaManager();
	$metaDB->open_read() || raise(
	    7, "cannot open meta database", 'error'
	    );
	my $ids = $metaDB->search( { 'resource-type' => 'branch',
				     'ONE_OF_gid'    => join(',',@{$groups} ) } );
	$metaDB->close();
	my %readable = ();
	foreach ( @{$ids} ){
	    my ( $s, $b ) = split( /\// );
	    $readable{$s}++;
	}
	@slots = sort keys %readable;
    }


    # Build array ref to store entries for result hash
    my $entries = [];
    foreach my $slot_name (@slots) {
        push(
            @$entries,
            {   'kind'  => 'slot',
                'name'  => [$slot_name],
                'perm'  => ['drwrwrw'],
                'owner' => ['root'],
                'group' => ['users'],
            }
        );
    }

    # Build hash ref for result
    my $result = {
        'path'  => '/',
        'entry' => $entries,
    };

    return $result;
}


=head2 C<existent>

 $exist = &LetsMT::Repository::StorageManager::existent (
     path => $path,
     rev  => $revision,
     uid  => $uid,
     gid  => $gid,
 )

Check for the existence of a given path.

Returns: true or false

=cut

sub existent {
    my %args    = @_;
    my $pathref = $args{path}  or raise( 12, "parameter path in existent", 'warn' );
    $pathref = [ @{$pathref} ];    #make copy so we can modify it
    my $uid = $args{uid}  or raise( 12, "parameter uid in existent", 'warn' );
    my $gid = $args{gid};

    my $slot       = shift( @{$pathref} );
    my $branch     = shift( @{$pathref} );
    my $targetfile = pop( @{$pathref} ) || "";
    my $grpobj     = LetsMT::Repository::GroupManager::get_group($gid);

    raise( 12, "slot parameter", 'warn' ) unless ( defined $slot   );
    raise( 6,  "slot $slot",     'warn' ) unless ( defined $branch );
    my $slotobj   = &_get_slot( name => $slot ) or return 0;
    my $branchobj = &_get_branch(
        name => $branch,
        user => $uid,
        slot => $slot,
    ) or return 0;
    raise( 14, "$uid has no read permission on $slot/$branch", 'warn' )
        unless ( $branchobj->may_read( $uid,
                &LetsMT::Repository::GroupManager::get_groups_for_user($uid)
            )
        );

    my $vc = new LetsMT::Repository::Storage(
        $slotobj->type
    ) or raise( 9, "Storage Backend", 'error' );

    my $dir = join( '/', @{$pathref} );
    return $vc->is_path(
        repos  => $slot,
        branch => $branch,
        user   => $uid,
        dir    => $dir,
        file   => $targetfile,
        rev    => $args{rev},
    );
}


=head2 C<download_storage>

 &LetsMT::Repository::StorageManager::download_storage (
     path    => $path,
     uid     => $uid,
     archive => $archive,
     target  => $target,
 )

Prepare download of the given path by writing the contents to the given target.
If C<$archive> is "no" or 0, don't make a zip file of it.

Returns: nothing on success (an exception is raised on failure)

FIXME: return true on success.

=cut

sub download_storage {
    my %args    = @_;
    my $pathref = $args{path}  or raise( 12, "parameter path in download_storage", 'warn' );
    $pathref = [ @{$pathref} ];    #make copy so we can modify it
    my $uid = $args{uid}  or raise( 12, "parameter uid in download_storage", 'warn' );
    my $archive = $args{archive};
    my $target  = $args{target};
    my $slot    = shift( @{$pathref} );

    $archive = defined($archive) && $archive =~ /^(no|0)$/i ? 0 : 1;
    raise( 14, "download on top level", 'warn' )  unless ( defined $slot && length $slot );

    my $slotobj = &_get_slot( name => $slot );
    raise( 6, "slot $slot", 'warn' )  unless ($slotobj);
    raise( 14, "download on slot level", 'warn' )  unless ( scalar @{$pathref} );
    my $branch = shift( @{$pathref} );

    ### list contents of a branch
    my $branchobj = &_get_branch(
        user => $uid,
        slot => $slot,
        name => $branch,
    ) or raise( 14, "branch $branch", 'warn' );

    #unlink($target);    ## race condition from here to checkout

    my $vc = new LetsMT::Repository::Storage(
        $slotobj->type
    ) or raise( 9, "Storage Backend", 'error' );

    $vc->export(
        repos   => $slot,
        src     => join( '/', $branchobj->name, @{$pathref} ),
        trg     => $target,
        rev     => $args{rev},
        uid     => $uid,
        archive => $archive,
    );
}


=head2 C<delete_storage>

 &LetsMT::Repository::StorageManager::delete_storage ($pathref, $user)

Delete the given path.

FIXME: Only makes sense on rev=HEAD

Returns: an XML-formatted string indicating success.

=cut

sub delete_storage {
    my ( $pathref, $user ) = @_;
    $pathref = [ @{$pathref} ];    #make copy so we can modify it
    my $slot   = shift( @{$pathref} );
    my $branch = shift( @{$pathref} );

    raise( 13, "Delete on global level", 'warn' ) unless ( defined $slot );

    if ( ! defined $branch ) {
        &delete_storage_slot(
            uid  => $user,
            slot => $slot
        ) or raise( 16, "slot $slot", 'warn' );
    }
    else {
        my $branchobj = &_get_branch(
            name => $branch,
            user => $user,
            slot => $slot
        ) or raise( 6, "branch $slot/$branch", 'warn' );
        raise(
            14,
            "'$user' has no write permission on $slot/$branch",
            'warn'
        ) unless ( $branchobj->may_write(
                $user,
                &LetsMT::Repository::GroupManager::get_groups_for_user( $user )
            )
        );

        my $slotobj = &_get_slot(
            name => $slot
        ) or raise(
            11,
            "strange error: branch $slot/$branch exists, but not $slot. May be a race-condition",
            'warn'
        );

        my $vc = new LetsMT::Repository::Storage(
            $slotobj->type
        ) or raise( 9, "Storage Backend", 'error' );

        raise(
            6,
            'removal target /' . join( '/', $slot, $branch, @{$pathref} ),
            'warn'
        ) unless (
            $vc->is_path(
                repos  => $slot,
                branch => $branch,
                dir    => join( '/', @{$pathref} ),
            )
        );

        $vc->remove(
            repos => $slot,
            dir   => join( '/', $branch, @{$pathref} ),
            user  => $user
        );

        ### delete of branch requested
        $branchobj->delete() unless ( scalar @{$pathref} );
    }
}


=head2 C<delete_storage_slot>

 &LetsMT::Repository::StorageManager::delete_storage_slot (
     uid => uid,
     slot => slot,
 )

Delete a slot from the resource repository.

Returns: true (an exception is raised on failure).

=cut

sub delete_storage_slot {
    my %args = @_;
    my $uid  = $args{uid}   or raise( 12, "parameter uid", 'warn' );
    my $slot = $args{slot}  or raise( 12, "parameter slot", 'warn' );
    my %user_visible_branches = ();
    my @other_branches        = ();
    my $groups = &LetsMT::Repository::GroupManager::get_groups_for_user($uid);
    my $slotobj = &_get_slot( name => $slot );

    my $vc = new LetsMT::Repository::Storage( $slotobj->type )
        or raise( 9, "Storage Backend", 'error' );

    raise( 6, "slot $slot", 'warn' ) unless ($slotobj);

    my $branchobj = &_get_branch( user => $uid, slot => $slot );
    if ($branchobj) {
        do {
            raise(
                14,
                "delete on slot $slot with branch "
                    . $branchobj->name
                    . " that $uid has no write permission on",
                'warn'
            ) unless ( $branchobj->may_write( $uid, $groups ) );
            $user_visible_branches{ $branchobj->name } = 1;
        } while ( $branchobj->restore_next() );
    }

    $branchobj = &_get_branch(
        user => $uid,
        slot => $slot,
        superuser_view => 1,
    );
    if ($branchobj) {
        do {
            push( @other_branches, $branchobj->name )
                unless ( $user_visible_branches{ $branchobj->name } );
        } while ( $branchobj->restore_next() );
    }

    raise(
        14,
        "slot $slot contains branches that $uid may not read ("
            . join( ',', @other_branches ) . ")",
        'warn'
    ) unless ( scalar(@other_branches) == 0 );

    ## delete all branches
    foreach my $branch ( keys %user_visible_branches ) {
        &delete_storage( [ $slot, $branch ], $uid );
    }

    ## delete slot
    $vc->remove(
        repos => $slot,
        user  => $uid,
    );
    $slotobj->delete();

    return 1;
}


=head2 C<put_access>

 &LetsMT::Repository::StorageManager::put_access ($pathref, $uid, $gid)

Change the group setting of a branch.

Returns: an XML-formatted string indicating success.

=cut

sub put_access {
    my ( $pathref, $uid, $gid ) = @_;
    $pathref = [ @{$pathref} ];    #make copy so we can modify it
    my $slot   = shift( @{$pathref} );
    my $branch = shift( @{$pathref} );

    raise( 12, 'gid', 'warn' ) unless ($gid);

    my $branchobj = &_get_branch(
        name => $branch,
        user => $uid,
        slot => $slot
    ) or raise( 6, "$slot/$branch", 'warn' );
    raise(
        14,
        "user '$uid', has no write permission on $slot/$branch",
        'warn'
    ) unless (
        $branchobj->may_write(
            $uid,
            &LetsMT::Repository::GroupManager::get_groups_for_user($uid)
        )
    );
    $branchobj->grp($gid);
    $branchobj->save;
}


=head2 C<get_access>

 &LetsMT::Repository::StorageManager::get_access ($result_ref, $pathref, $uid)

Get the group settings for the branches in a slot,
the group setting of a single branch
or a resource below branch level.

Returns: nothing, writes hash ref to in-argument $resutl_ref

=cut

sub get_access {
    my ( $result_ref, $pathref, $uid ) = @_;

    raise( 12, 'uid', 'warn' ) unless $uid;    # Missing uid

    my $path = join '/', @{$pathref};

    $pathref = [ @{$pathref} ];                #make copy so we can modify it
    my $slot   = shift( @{$pathref} );
    my $branch = shift( @{$pathref} );
    my $rest   = shift( @{$pathref} );

    raise( 12, 'slot', 'warn' ) unless $slot;    # Missing uid

    my $branchobj = &_get_branch(
        name => $branch,
        user => $uid,
        slot => $slot
    ) or raise( 6, $path, 'warn' );

    my $entries = [];
    do {
        push(
            @$entries,
            {   'kind' => 'branch',
                #^^ TODO: should reflect the actual kind of the entry
                'path' => $path . (
                        ( $branchobj->name && !$branch )
                        ? '/' . $branchobj->name
                        : ''
                    ),
                'group' => [ $branchobj->grp ],
                'owner' => [ $branchobj->owner ],
            }
        );
    } while ( $branchobj->restore_next() );

    $$result_ref = {
        'path'  => $path,
        'entry' => $entries,
    };
}


###### CREATE/GET PERSISTENT OBJECTS ################

=head2 C<_get_branch>

 _get_branch (
     name           => $name,
     user           => $user,
     slot           => $slot,
     superuser_view => $superuser_view,
 )

Try to retrieve Branch objects from the datastore,
using the effective user's permissions.
If superuser_view is true, then all objects can be seen.

Returns: a Branch object or false.

=cut

sub _get_branch {
    my %params = @_;
    map { $params{$_} = "" unless ( defined( $params{$_} ) ) }
        qw/ name user slot superuser_view /;

    my $groups = LetsMT::Repository::GroupManager::get_groups_for_user(
        $params{user}
    );

    my $obj = new LetsMT::Repository::StorageManager::Branch();
    return $obj->find(
        name           => $params{name},
        user           => $params{user},
        groups         => $groups,
        slot           => $params{slot},
        superuser_view => $params{superuser_view},
    );
}


=head2 C<_get_slot>

 _get_slot (name => $name)

Try to retrieve Slot objects from the datastore.

Returns: a Slot object or false.

=cut

#### Returns a Slot object or false.

sub _get_slot {
    my %params = @_;
    map { $params{$_} = "" unless ( defined( $params{$_} ) ) }
        qw/ name /;

    my $obj = new LetsMT::Repository::StorageManager::Slot();
    return $obj->find(
        name => $params{name}
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
