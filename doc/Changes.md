
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


## Planned changes

* add support for aligning two given files (extra link parameter + align action)
* request for listing potentially parallel documents
