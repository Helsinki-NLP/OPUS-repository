
# Recent changes

There is quite a lot of changes since the latest release from the original LetsMT! project. Here are some of the changes in the software and API.


* we now support git as the default backend
* batch jobs are now handled with SLURM (forget about gridengine)
* Apache Tika is updated and uses now version 1.18 and runs via a server
* UDPipe is integrated for sentence splitting (and more in the future)
* pdf2xml is integrated as pdf import method `combined` (but this is VERY slow!)


## Changes to the storage API


* listing storages checks now whether there is a readable branch for the selected user (before all slots are always listed); for example, to list all slots that have a readable branch for user `user1` do:

```
 $LETSMT_CONNECT -X GET "$LETSMT_URL/storage?uid=user1"
```

* use special user `admin` for listing all slots in the database:

```
 $LETSMT_CONNECT -X GET "$LETSMT_URL/storage?uid=admin"
```


## Changes to the job API

* list all jobs in the SLURM job queue:

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/job?uid=user1"
```

TODO: should we restrict this for admin users only? Is it possible to list only user-specific jobs? Is it easy to find back the actual job description file from the job listing above?


* align jobs for selected file pairs: add parameter `trg` to specify target file to be aligned

```
$LETSMT_CONNECT -X PUT "$LETSMT_URL/job/slot1/user1/xml/fi/2.html.xml?uid=user1&trg=xml/sv/2.html.xml&run=align"
```

* align jobs for alignment candidates (the ones detected by import processes or `detect_translations` or `detect_unaligned`) for specific resources or for entire subtrees:

```
$LETSMT_CONNECT -X PUT "$LETSMT_URL/job/slot1/user1/xml/en/2.html.xml?uid=user1&run=align_candidates"
$LETSMT_CONNECT -X PUT "$LETSMT_URL/job/slot1/user1/xml/fi?uid=user1&run=align_candidates"
```

* try to find parallel documents by running the commands `detect_translations` (all potentially parallel documents including the ones that are already aligned) or `detect_unaligned` (potentially parallel documents that are not yet aligned):

```
$LETSMT_CONNECT -X PUT "$LETSMT_URL/job/slot1/user1/xml/en?uid=user1&run=detect_translations"
$LETSMT_CONNECT -X PUT "$LETSMT_URL/job/slot1/user1/xml/fi?uid=user1&run=detect_untranslated"
```


## Changes to the import and alignment parameters

* new import parameter: `ImportPara_autoalign = on/off` - automatically detect and align parallel documents (default = on)
* new PDF import mode: `ImportPara_mode = combined` - use pdf2xml for conversion from PDF
* new default sentence splitter: `udpipe` (before it was europarl)
* new default aligner: `hunalign` (it was `bisent` before)


If `autoalign` is off the system will still try to find parallel documents and the result will be stored in the metadata for each monolingual corpus file. The key is `align-candidate` and all candidates can be found by issuing this query on the specific slot (`slot1` in this example):

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/metadata/slot1/user1?ENDS_WITH_align-candidates=xml&uid=user1&type=recursive&action=list_all"
```

You can also run this command for specific subtrees of the repository, for example English files only:

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/metadata/slot1/user1/xml/en?ENDS_WITH_align-candidates=xml&uid=user1&type=recursive&action=list_all"
```

* the options for fuzzy matching of corpusfilenames are currently switched off (too expensive as a query for large corpora with many corpusfiles!)



## Planned changes

* add support for aligning two given files (extra link parameter + align action)
* request for listing potentially parallel documents
