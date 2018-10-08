
# Aligning files in the repository

With the default settings, files with identical names but different language sub-directory will be sentence-aligned with each other when importing them to the repository. Automatic alignment can also be switched off and can always be influenced by import/alignment parameters.

Any import/alignment parameter can be set on three levels:
* user-level
* corpus-level (for a selected user-branch in a specific slot)
* file-level (any path in the repository)

The parameters are read in the same order as specified above and overwrite each other in case they are specified on several levels. That means that file-level parameters overwrite corpus-level parameters, which overwrite user-level settings.


## Switching off auto-alignment


* creating a new user and corpus

```
$LETSMT_CONNECT -X PUT "$LETSMT_URL/group/testuser/testuser?uid=testuser"
$LETSMT_CONNECT -X PUT "$LETSMT_URL/storage/testslot/testuser?uid=testuser"
```

* switching off auto alignment on corpus-level

```
$LETSMT_CONNECT -X POST "$LETSMT_URL/metadata/testslot/testuser?uid=testuser&ImportPara_autoalign=off"
$LETSMT_CONNECT -X GET "$LETSMT_URL/metadata/testslot/testuser?uid=testuser"
```
```xml
<letsmt-ws version="56">
  <list path="">
    <entry path="testslot/testuser">
      <name>testuser</name>
      <ImportPara_autoalign>off</ImportPara_autoalign>
      <acces>2018-10-08 08:50:20</acces>
      <create>2018-10-08 08:50:20</create>
      <gid>public</gid>
      <modif>2018-10-08 08:50:20</modif>
      <owner>testuser</owner>
      <resource-type>branch</resource-type>
      <slot>testslot</slot>
      <status>updated</status>
      <uid>testuser</uid>
    </entry>
  </list>
  <status code="0" location="/metadata/testslot/testuser" operation="GET" type="ok">Found matching path ID. Listing all of its properties</status>
</letsmt-ws>
```

* upload some files and import them

```
$LETSMT_CONNECT -X PUT "$LETSMT_URL/storage/testslot/testuser/uploads/html/en/100.html?uid=testuser&action=import" --form payload=@en/100.html
$LETSMT_CONNECT -X PUT "$LETSMT_URL/storage/testslot/testuser/uploads/html/fr/100.html?uid=testuser&action=import" --form payload=@fr/100.html
$LETSMT_CONNECT -X PUT "$LETSMT_URL/storage/testslot/testuser/uploads/html/ru/100.html?uid=testuser&action=import" --form payload=@ru/100.html
```

Those files should not get aligned even though they have the same name but we can look for alignment candidates that have been identified (see the field `align-candidates`):

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/metadata/testslot/testuser?ENDS_WITH_align-candidates=xml&uid=testuser&type=recursive&action=list_all"
```
```xml
<letsmt-ws version="56">
  <list path="testslot/testuser/">
    <entry path="testslot/testuser/xml/en/100.xml">
      <align-candidates>xml/ru/100.xml,xml/fr/100.xml</align-candidates>
      <gid>public</gid>
      <language>en</language>
      <owner>testuser</owner>
      <parsed>ud/en/100.xml</parsed>
      <resource-type>corpusfile</resource-type>
      <size>106</size>
      <status>updated</status>
    </entry>
    <entry path="testslot/testuser/xml/fr/100.xml">
      <align-candidates>xml/ru/100.xml</align-candidates>
      <gid>public</gid>
      <language>fr</language>
      <owner>testuser</owner>
      <parsed>ud/fr/100.xml</parsed>
      <resource-type>corpusfile</resource-type>
      <size>97</size>
      <status>updated</status>
    </entry>
  </list>
  <status code="0" location="/metadata/testslot/testuser" operation="GET" type="ok">Found 2 matching entries</status>
</letsmt-ws>
```

Note that there can be multiple candidates for each file. Also note that they are only listed in one direction (language IDs are alphabetically sorted), i.e. the French file is listed as alignment candidate for the English file but not the other way around.


## Other modes of finding parallel documents

* fuzzy name matching: ... TODO ...
* content-based matching: ... TODO ...