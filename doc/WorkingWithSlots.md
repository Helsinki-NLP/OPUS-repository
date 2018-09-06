
# General principles

* a slot is a repository with a unique name
* each slot can have multiple branches, typically named by the user name of the user who owns it
* each branch in a slot is connected to a group (of users)
* the default group of a branch is `public` (= all users can read)
* the group can be set when creating a slot/branch (see examples below)


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



# Clone an existing branch



# Delete a branch



# Delete the entire slot




# BUGS

* creating a slot without branch works but cannot be found by GET
* other users can create sub-dirs in slots/branches they do not own
* any user can delete an entire slot