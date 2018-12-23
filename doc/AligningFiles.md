
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


## Align individual file pairs

* align jobs for selected file pairs: add parameter `trg` to specify target file to be aligned and run align command

```
$LETSMT_CONNECT -X PUT "$LETSMT_URL/job/slot1/user1/xml/fi/2.html.xml?uid=user1&trg=xml/sv/2.html.xml&run=align"
```


## Finding parallel documents

* try to find parallel documents by running the commands `detect_translations` (all potentially parallel documents including the ones that are already aligned) or `detect_unaligned` (potentially parallel documents that are not yet aligned):

```
$LETSMT_CONNECT -X PUT "$LETSMT_URL/job/testslot/testuser/xml/en?uid=testuser&run=detect_translations"
$LETSMT_CONNECT -X PUT "$LETSMT_URL/job/testslot/testuser/xml/fr?uid=testuser&run=detect_unaligned"
```

* default search method is to find documents with identical names and paths (except the language-specific subdir); there is also a mode for fuzzy matching of names: `similar-names`: set the parameter `AlignPara_search_parallel` to `similar-names`

```
$LETSMT_CONNECT -X POST "$LETSMT_URL/metadata/testslot/testuser/uploads?uid=testuser&AlignPara_search_parallel=similar-names"
``` 

* the fuzzy matching mode now also includes a test whether file names (and paths) only differ in a language name or identifier. This can also be used without fuzzy matching mode by adding `_with_lang` to the seatch mode:

```
$LETSMT_CONNECT -X POST "$LETSMT_URL/metadata/testslot/testuser/uploads?uid=testuser&AlignPara_search_parallel=identical-names_with_lang"
``` 



* TODO: matching of translated document names (difficult), content-based matching of documents (expensive and difficult); could we use existing external tools such as bitextor?



## Align all alignment candidates

* align jobs for alignment candidates (the ones detected by import processes or `detect_translations` or `detect_unaligned`) for specific resources or for entire subtrees:

```
$LETSMT_CONNECT -X PUT "$LETSMT_URL/job/testslot/testuser/xml/en/100.xml?uid=user&run=align_candidates"
$LETSMT_CONNECT -X PUT "$LETSMT_URL/job/testslot/testuser/xml/fr?uid=testuser&run=align_candidates"
$LETSMT_CONNECT -X PUT "$LETSMT_URL/job/testslot/testuser/xml?uid=testuser&run=align_candidates"
```

