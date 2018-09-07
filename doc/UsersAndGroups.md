# Creating users and groups

* Create a user by creating a group with the same name owned by that user, for example users `user1` and `user2`:

```
$LETSMT_CONNECT -X POST "$LETSMT_URL/group/user1?uid=user1"
$LETSMT_CONNECT -X POST "$LETSMT_URL/group/user2?uid=user2"
```

A new user is automatically added to the `public` group that is owned by a special user `admin` (NOTE: don't allow users with the name `admin`!):

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/group/public?uid=user1"
```

* any user can create new groups

```
$LETSMT_CONNECT -X POST "$LETSMT_URL/group/mygroup?uid=user1"
```

* only the owner of a group (the user who created it) is allowed to add (or delete) new users to that group:

```
$LETSMT_CONNECT -X PUT "$LETSMT_URL/group/mygroup/user2?uid=user1"
$LETSMT_CONNECT -X GET "$LETSMT_URL/group/mygroup?uid=user1"
```

Note that anyone can view groups. uid is only checked to be set to something (even to user names that do not exist). (TODO: should that be changed?)



# Membership in groups

There is a special command to show information about a specific user including membership in groups (see `member_of` in the result of the request). Note that uid needs to match the username in the path:

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/group/user1?uid=user1&action=showinfo"

<letsmt-ws version="55">
  <list path="group/user1">
    <entry id="user1" kind="user info">
      <member>user1</member>
      <member_of>mygroup,public</member_of>
      <my_group>user1</my_group>
    </entry>
  </list>
  <status code="0" location="/group/user1" operation="GET" type="ok"></status>
</letsmt-ws>
```


# Deleting users

The software does not handle separate lists of users but a user can effectively be deleted by removing the name from all groups. Note that only the special user `admin` can delete users from the `public` group.


```
$LETSMT_CONNECT -X DELETE "$LETSMT_URL/group/mygroup/user2?uid=user1"
$LETSMT_CONNECT -X DELETE "$LETSMT_URL/group/user2/user2?uid=user2"
$LETSMT_CONNECT -X DELETE "$LETSMT_URL/group/public/user2?uid=admin"
```

TODO: We should have a more convenient way of deleting users from the system!


# User-specific system configuration

Each user can have specific configurations for importing and aligning data. The group API allows to specify various parameters that will be stored in the group database. Those parameters can be overwritten by parameters for specific resources but will be used as default if no other parameters are given for the resources to be handled. The group API allows to add arbitrary key-value pairs to be added to the user specification. This may include other types of information that we want to store together with the user name.


```
$LETSMT_CONNECT -X POST "$LETSMT_URL/group/user1?uid=user1&email=my.email@host.org"
...
$LETSMT_CONNECT -X GET "$LETSMT_URL/group/user1?uid=user1&action=showinfo"

<letsmt-ws version="55">
  <list path="group/user1">
    <entry id="user1" kind="user info">
      <email>my.email@host.org</email>
      <member>user1</member>
      <member_of>user1,mygroup,public</member_of>
      <my_group>user1</my_group>
    </entry>
  </list>
  <status code="0" location="/group/user1" operation="GET" type="ok"></status>
</letsmt-ws>
```
