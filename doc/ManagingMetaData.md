
# General principles

* every path in storage can have a record of key-value pairs attached to it
* actually, the path does not even have to exist in storage ...
* values can be numeric, strings or comma-separated lists
* anyone can read them (at the moment) - TODO: we should probably be more restrictive 


# Retrieve metadata record


# Search the database

* you can search the entire database by firing a query with a path to the metadata API, for example find all resources owned by user1 (note that this can be a very long list!)

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/metadata?owner=user1&uid=user1"

<letsmt-ws version="55">
  <list path="">
    <entry path="slot1/user1" />
    <entry path="slot2/user1" />
    ...
    <entry path="slot1/user1/xml/fi-tr/5.xml" />
    ...
  </list>
  <status code="0" location="/metadata" operation="GET" type="ok">Found xxx matching entries</status>
</letsmt-ws>
```

* you can also search within a certain sub-tree of all possible paths by adding the root path to the URL and by adding the special action `type=recursive`

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/metadata/slot1/user1/xml/fi-tr?owner=user1&uid=user1&type=recursive"

<letsmt-ws version="55">
  <list path="">
    <entry path="slot1/user1/xml/fi-tr/1.xml" />
    <entry path="slot1/user1/xml/fi-tr/2.xml" />
    ...
  </list>
  <status code="0" location="/metadata" operation="GET" type="ok">Found xxx matching entries</status>
</letsmt-ws>
```

Any kind of path can be used to recursively search within that path. (Internally this is solved by adding the condition `STARTS_WITH__ID=path` to the query, which looks for the prefix `path` in the special DB field `_ID_`.



# Special conditions for metadata search

You can add a few special prefix-strings to a key of a query to do certain types of searches:

* `STARTS_WITH_`: search for values that start with the given string
* `ENDS_WITH_`: search for values that end with the given string
* `ONE_OF_`: interprete the value in the DB as a comma-separated list and match any field that includes at least ONE of the values given in the query (also comma separated)
* `ALL_OF_`: interprete the value in the DB as a comma-separated list and match any field that includes ALL of the values given in the query (also comma separated)
* `MAX_`: for numeric values - match fields that have at most the given value from the query (<=)
* `MIN_`: for numeric values - match fields that have at least the given value from the query (>=)


```
## return all Swedish and all Finnish resources owned by user1
$LETSMT_CONNECT -X GET "$LETSMT_URL/metadata?uid=user1&owner=user1&ONE_OF_language=sv,fi"

## return all alignments between Swedish and Finnish resources owned by user1
$LETSMT_CONNECT -X GET "$LETSMT_URL/metadata?uid=user1&owner=user1&resource-type=sentalign&ALL_OF_language=sv,fi"

## return all corpus files owned by user1 with a maximum size of 1000 bytes
$LETSMT_CONNECT -X GET "$LETSMT_URL/metadata?uid=user1&owner=user1&resource-type=corpusfile&MAX_size=1000"

## return all corpus files owned by user1 with a minimum size of 500 bytes
$LETSMT_CONNECT -X GET "$LETSMT_URL/metadata?uid=user1&owner=user1&resource-type=corpusfile&MIN_size=500"
```


It is also possible to specify special actions to be performed on the resulting data records:

* `action=MAX_field`: return the maximum value of the key `field` among the matching DB records
* `action=MIN_field`: return the minimum value of the key `field` among the matching DB records
* `action=SUM_field`: return the sum of the values in `field` among the matching DB records

```
## return the size of the biggest corpus file owned by user1
$LETSMT_CONNECT -X GET "$LETSMT_URL/metadata?uid=user1&owner=user1&resource-type=corpusfile&action=MAX_size"

## return the size of the smallest corpus file owned by user1
$LETSMT_CONNECT -X GET "$LETSMT_URL/metadata?uid=user1&owner=user1&resource-type=corpusfile&action=MIN_size"

## return the total size of all corpus files owned by user1
$LETSMT_CONNECT -X GET "$LETSMT_URL/metadata?uid=user1&owner=user1&resource-type=corpusfile&action=SUM_size"
```


# Other search examples


* search for public storage-branches:

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/metadata?uid=user1&gid=public&resource-type=branch"

<letsmt-ws version="55">
  <list path="">
    <entry path="slot5/user3" />
    <entry path="slot5/user4" />
    ...
  </list>
  <status code="0" location="/metadata" operation="GET" type="ok">Found 10 matching entries</status>
</letsmt-ws>
```


* search for imported files (status = imported)

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/metadata?status=imported&uid=user"
<
letsmt-ws version="55">
  <list path="">
    <entry path="corpus2/user/uploads/html/small.tar.gz" />
    <entry path="corpus/user/uploads/html.tar.gz" />
    <entry path="corpus/user/uploads/small.tar.gz" />
    <entry path="corpus2/user/uploads/html.tar.gz" />
    <entry path="slot_name808360964598/user_id_621349166935/uploads/tmx/öäå.tmx" />
  </list>
  <status code="0" location="/metadata" operation="GET" type="ok">Found 5 matching entries</status>
</letsmt-ws>
```

TODO: How can we search within a specific slot/branch only?


* search for imported files owned by a specific user 

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/metadata?status=imported&owner=user&uid=user"
<
letsmt-ws version="55">
  <list path="">
    <entry path="corpus2/user/uploads/html/small.tar.gz" />
    <entry path="corpus/user/uploads/html.tar.gz" />
    <entry path="corpus/user/uploads/small.tar.gz" />
    <entry path="corpus2/user/uploads/html.tar.gz" />
    <entry path="slot_name808360964598/user_id_621349166935/uploads/tmx/öäå.tmx" />
  </list>
  <status code="0" location="/metadata" operation="GET" type="ok">Found 5 matching entries</status>
</letsmt-ws>
```


* search for all monolingual corpus files (resource-type=corpusfile) with a size of at least 300 bytes

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/metadata?uid=user&owner=user&MIN_size=300&resource-type=corpusfile"

<letsmt-ws version="55">
  <list path="">
    <entry path="corpus/user/xml/en/207.xml" />
    <entry path="corpus/user/xml/et/135.xml" />
    <entry path="corpus/user/xml/sv/207.xml" />
    <entry path="corpus/user/xml/fi/135.xml" />
    <entry path="corpus/user/xml/so/207.xml" />
    <entry path="corpus/user/xml/tr/207.xml" />
    <entry path="corpus/user/xml/ru/207.xml" />
    <entry path="corpus/user/xml/es/207.xml" />
    <entry path="corpus/user/xml/zh/207.xml" />
    <entry path="corpus/user/xml/fr/207.xml" />
    <entry path="corpus/user/xml/ru/135.xml" />
    <entry path="corpus/user/xml/ar/207.xml" />
    <entry path="corpus/user/xml/fa/207.xml" />
    <entry path="corpus/user/xml/en/135.xml" />
    <entry path="corpus/user/xml/et/207.xml" />
  </list>
  <status code="0" location="/metadata" operation="GET" type="ok">Found 15 matching entries</status>
</letsmt-ws>
```


* compute the sum of all size attributes for all corpus files owned by user `user`

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/metadata?uid=user&owner=user&resource-type=corpusfile&action=SUM_size"

<letsmt-ws version="55">
  <list path="">
    <entry type="search result">
      <SUM_size>350791</SUM_size>
      <count>7410</count>
    </entry>
  </list>
  <status code="0" location="/metadata" operation="GET" type="ok">Found 7410 matching entries</status>
</letsmt-ws>
```


* search for all sentence alignment files (resource-type=sentalign) involving Swedish (ONE_OF_language=sv)

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/metadata?uid=user&owner=user&ONE_OF_language=sv&resource-type=sentalign"

<letsmt-ws version="55">
  <list path="">
    <entry path="corpus/user/xml/en-sv/4.html.xml" />
    <entry path="corpus/user/xml/en-sv/1.html.xml" />
    <entry path="corpus/user/xml/en-sv/7.html.xml" />
    <entry path="corpus/user/xml/en-sv/5.html.xml" />
    <entry path="corpus/user/xml/en-sv/9.html.xml" />
    <entry path="corpus/user/xml/en-sv/2.html.xml" />
    <entry path="corpus/user/xml/fi-sv/4.html.xml" />
    <entry path="corpus/user/xml/fi-sv/1.html.xml" />
...
```

* search for all sentence alignment files (resource-type=sentalign) for Finnish-Swedish (ALL_OF_language=fi,sv)

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/metadata?uid=user&owner=user&ALL_OF_language=fi,sv&resource-type=sentalign"

<letsmt-ws version="55">
  <list path="">
    <entry path="corpus/user/xml/fi-sv/4.html.xml" />
    <entry path="corpus/user/xml/fi-sv/1.html.xml" />
    <entry path="corpus/user/xml/fi-sv/7.html.xml" />
    <entry path="corpus/user/xml/fi-sv/5.html.xml" />
    <entry path="corpus/user/xml/fi-sv/9.html.xml" />
    <entry path="corpus/user/xml/fi-sv/2.html.xml" />
    <entry path="corpus/user/xml/fi-sv/262.xml" />
    <entry path="corpus/user/xml/fi-sv/215.xml" />
...
```

Note the difference beetween using the conditions `ALL_OF_language=fi,sv` and `language=fi,sv`. Both work the same in this case but all of allows to have unordered list to match the given value. So, `ALL_OF_language=sv,fi` gives the same result as specifying `ALL_OF_language=fi,sv` whereas `language=fi,sv` only matches the exact string `fi,sv`. ALL_OF_ also allows to specify subsets.


* find all files aligned to a certain corpus file (`xml/en/383.xml`)

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/metadata/corpus/user?ONE_OF_aligned_with=xml/en/383.xml&uid=user&type=recursive"


<letsmt-ws version="55">
  <list path="">
    <entry path="corpus/user/xml/zh/383.xml" />
    <entry path="corpus/user/xml/ru/383.xml" />
    <entry path="corpus/user/xml/fr/383.xml" />
    <entry path="corpus/user/xml/tr/383.xml" />
    <entry path="corpus/user/xml/so/383.xml" />
    <entry path="corpus/user/xml/fi/383.xml" />
    <entry path="corpus/user/xml/es/383.xml" />
    <entry path="corpus/user/xml/ar/383.xml" />
    <entry path="corpus/user/xml/et/383.xml" />
    <entry path="corpus/user/xml/fa/383.xml" />
    <entry path="corpus/user/xml/sv/383.xml" />
  </list>
  <status code="0" location="/metadata" operation="GET" type="ok">Found 11 matching entries</status>
</letsmt-ws>
```


* restrict this to public data

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/metadata?ONE_OF_aligned_with=xml/en/383.xml&gid=public&uid=user"
```

TODO: Does this really work especially if the group is changed for the slot after importing resources?




# TODO

* results only for things that the user has read permissions for
