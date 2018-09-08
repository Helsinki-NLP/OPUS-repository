
# General principles of storage slots

* a slot is a repository with a unique name (different [storage backends](StorageBackends.md) are possible)
* each slot can have multiple branches, typically named by the user name of the user who owns it
* each branch in a slot is connected to a group (of users), see [users and groups](UsersAndGroups.md) for more details on user management
* the default group of a branch is `public` (= all users can read)
* the group can be set when creating a slot/branch (see examples below)
* every resource in every slot can have arbitrary metadata (see [managing metadata](ManagingMetaData.md))



# Create a few test users, groups

* create 3 users `user1`, `user2`, `user3`

```
$LETSMT_CONNECT -X POST "$LETSMT_URL/group/user1/user1?uid=user1"
$LETSMT_CONNECT -X POST "$LETSMT_URL/group/user2/user2?uid=user2"
$LETSMT_CONNECT -X POST "$LETSMT_URL/group/user3/user3?uid=user3"
```

* `user1` creates a group `group12` and adds `user2` to that group

```
$LETSMT_CONNECT -X POST "$LETSMT_URL/group/group12/user1?uid=user1"
$LETSMT_CONNECT -X PUT "$LETSMT_URL/group/group12/user2?uid=user1"
```

* check public group:

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/group/public?uid=user1"
```

* check `group12` owned by `user1`

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/group/group12?uid=user1"
```



# Create a new public slot

* `user1` creates `slot1` with a branch named by the user name

```
$LETSMT_CONNECT -X PUT "$LETSMT_URL/storage/slot1/user1?uid=user1"
```

All slots are automatically `public` (see group settings). You can verify that using the access API:

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/access/slot1/user1?uid=user1"
```

All users can read the branch:

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/storage/slot1/user1?uid=user1"
$LETSMT_CONNECT -X GET "$LETSMT_URL/storage/slot1/user1?uid=user2"
$LETSMT_CONNECT -X GET "$LETSMT_URL/storage/slot1/user1?uid=user3"
```


# Create a private slot

* `user1` creates a private branch in a new `slot2`; `user2` and `user3` cannot read `slot2`

```
$LETSMT_CONNECT -X PUT "$LETSMT_URL/storage/slot2/user1?uid=user1&gid=user1"
$LETSMT_CONNECT -X GET "$LETSMT_URL/access/slot2/user1?uid=user1"
```

Only `user1` can read the branch:

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/storage/slot2/user1?uid=user1"
$LETSMT_CONNECT -X GET "$LETSMT_URL/storage/slot2/user1?uid=user2"
$LETSMT_CONNECT -X GET "$LETSMT_URL/storage/slot2/user1?uid=user3"
```


# Create a slot that is shared among selected users

* `user1` creates `slot3` with a branch named by the user name with permissions for group `group12`

```
$LETSMT_CONNECT -X PUT "$LETSMT_URL/storage/slot3/user1?uid=user1&gid=group12"
$LETSMT_CONNECT -X GET "$LETSMT_URL/access/slot3/user1?uid=user1"
```

Now read permissions are restricted. `user1` (the owner) and `user2` (member of group `group12`) can read the branch but not `user3` who is not in the same group

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/storage/slot3/user1?uid=user1"
$LETSMT_CONNECT -X GET "$LETSMT_URL/storage/slot3/user1?uid=user2"
$LETSMT_CONNECT -X GET "$LETSMT_URL/storage/slot3/user1?uid=user3"
```


# Change the group settings of a branch

The group settings can be changed using the `access` API:

* make `slot1` into a private slot for `user1`

```
$LETSMT_CONNECT -X PUT "$LETSMT_URL/access/slot1/user1?uid=user1&gid=user1"
$LETSMT_CONNECT -X GET "$LETSMT_URL/access/slot1/user1?uid=user1"
```

Now only `user1` is allowed to read from that branch:

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/storage/slot1/user1?uid=user1"
$LETSMT_CONNECT -X GET "$LETSMT_URL/storage/slot1/user1?uid=user2"
$LETSMT_CONNECT -X GET "$LETSMT_URL/storage/slot1/user1?uid=user3"
```



# Cloning branches


* create a new slot `slot5` with read permissions for group `group12`

```
$LETSMT_CONNECT -X PUT "$LETSMT_URL/storage/slot5/user1?uid=user1&gid=group12"
```

* `user2` clones the branch of `user1` in slot5

```
$LETSMT_CONNECT -X POST "$LETSMT_URL/storage/slot5/user1?uid=user2&action=copy&dest=user2"
```

* `user3` cannot do that because that user does not have read permissions for the branch of `user1`

```
$LETSMT_CONNECT -X POST "$LETSMT_URL/storage/slot5/user1?uid=user3&action=copy&dest=user3"
```

* interestingly, `user2` can do it for `user3` and `user2` cannot take it away from `user3` afterwards!

```
$LETSMT_CONNECT -X POST "$LETSMT_URL/storage/slot5/user1?uid=user2&action=copy&dest=user3"
```

* `user3` can now make his branch public and let other users read it as well

```
$LETSMT_CONNECT -X PUT "$LETSMT_URL/access/slot5/user3?uid=user3&gid=public"
$LETSMT_CONNECT -X GET "$LETSMT_URL/access/slot5/user3?uid=user3"
```

* `user3` can make changes to his own branch, for example adding a subdir xml, and a new user `user4` can clone the branch of `user3` (with the changes `user3` made after cloning from `user1`)


```
$LETSMT_CONNECT -X PUT "$LETSMT_URL/storage/slot5/user3/xml?uid=user3"
$LETSMT_CONNECT -X POST "$LETSMT_URL/group/user4/user4?uid=user4"
$LETSMT_CONNECT -X POST "$LETSMT_URL/storage/slot5/user3?uid=user4&action=copy&dest=user4"
```

* verify that this really worked:

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/storage/slot5/user1?uid=user1"
$LETSMT_CONNECT -X GET "$LETSMT_URL/storage/slot5/user2?uid=user2"
$LETSMT_CONNECT -X GET "$LETSMT_URL/storage/slot5/user3?uid=user3"
$LETSMT_CONNECT -X GET "$LETSMT_URL/storage/slot5/user4?uid=user4"
```


# Search for slots

* list all slots that have at least one readable branch for a given user

```
 $LETSMT_CONNECT -X GET "$LETSMT_URL/storage?uid=user1"
```
```xml
<letsmt-ws version="55">
  <list path="">
    <entry path="slot1" />
    <entry path="slot2" />
  </list>
  <status code="0" location="/metadata" operation="GET" type="ok">Found 2 matching entries</status>
</letsmt-ws>
```

* list all available slots (use special user `admin`)

```
 $LETSMT_CONNECT -X GET "$LETSMT_URL/storage?uid=admin"
```


* list all slots owned by a specific user:

```
 $LETSMT_CONNECT -X GET "$LETSMT_URL/metadata?owner=user1&uid=user1"
```
```xml
<letsmt-ws version="55">
  <list path="">
    <entry path="slot1/user1" />
    <entry path="slot2/user1" />
  </list>
  <status code="0" location="/metadata" operation="GET" type="ok">Found 2 matching entries</status>
</letsmt-ws>
```

* list all storage branches that are public (gid = `public`); note the additional condition of resource-type to skip all other kind of individual resources that are marked as public!

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/metadata?uid=user1&gid=public&resource-type=branch"
```
```xml
<letsmt-ws version="55">
  <list path="">
    <entry path="slot5/user3" />
    <entry path="slot5/user4" />
    ...
  </list>
  <status code="0" location="/metadata" operation="GET" type="ok">Found 10 matching entries</status>
</letsmt-ws>
```



# BUGS

* creating a slot without branch works but cannot be found by GET
* other users can create sub-dirs in slots/branches they do not own
