
# Batch job management

Since version 0.56 we now use SLURM as the default job management. This is much easier to set up and seems to be more robust as well. Forget about SGE and don't try to install the old gridengine anymore!


Jobs are submitted for importing and aligning documents and they are triggered either from the `job` API or automatically after a new upload to storage with the `action=import` flag added. Look at [importing files](ImportingFiles.md) for details.


* submitting a job for re-importing a file:

```
$LETSMT_CONNECT -X PUT "$LETSMT_URL/job/corpus333/user/uploads/small12.tar.gz?uid=user&run=reimport"
```


* listing all running jobs for user `user`

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/job?uid=user"
```
```xml
<letsmt-ws version="56">
  <list path="jobs">
    <entry name="job_1542837279_527304382" file="mycorpus/user/uploads/sv.tar.gz" id="761" job="mycorpus/user/jobs/import/uploads/sv.tar.gz.xml" status="RUNNING" />
  </list>
  <status code="0" location="job" operation="GET" type="ok" />
</letsmt-ws>
```

If `uid=admin` then all jobs for all users will be listed. NOTE: Currently `file` and `job` attribute will not be set when running with `admin` as user!


* searching for job description files for a given job ID:

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/metadata?uid=user&job_id=job_1541673288_768302220"
<letsmt-ws version="56">
  <list path="">
    <entry path="corpus/user/jobs/import/uploads/small.tar.gz" />
  </list>
  <status code="0" location="/metadata" operation="GET" type="ok">Found 1 matching entries</status>
</letsmt-ws>
```



* deleting a job using the job description file path

```
$LETSMT_CONNECT -X DELETE "$LETSMT_URL/job/corpus333/user/jobs/import/uploads/small12.tar.gz?uid=user"
```
```xml
<letsmt-ws version="56">
  <status code="0" location="/job/corpus333/user/jobs/import/uploads/small12.tar.gz" operation="DELETE" type="ok"></status>
</letsmt-ws>
```


* deleting a job using the job ID

```
$LETSMT_CONNECT -X DELETE "$LETSMT_URL/job?uid=user&job_id=job_1541676088_906142295"
```
```xml
<letsmt-ws version="56">
  <status code="0" location="/job" operation="DELETE" type="ok"></status>
</letsmt-ws>
```


* list all job description files owned by a specific user `user`

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/metadata?uid=opus&STARTS_WITH_job_id=job&owner=user"
```
```xml
<letsmt-ws version="56">
  <list path="">
    <entry path="corpus333/user/jobs/import/uploads/small11.tar.gz.xml" />
    <entry path="corpus333/user/jobs/import/uploads/small8.tar.gz.xml" />
  </list>
  <status code="0" location="/metadata" operation="GET" type="ok">Found 2 matching entries</status>
</letsmt-ws>
```

with all data fields:

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/metadata?uid=opus&STARTS_WITH_job_id=job&owner=user&action=list_all"
```


# New in the Job API

* job IDs are added to the metadata when running import and alignment (`job_id`) jobs:

```
$LETSMT_CONNECT -X PUT "$LETSMT_URL/job/corpus/user/uploads/small.tar.gz?uid=user&run=reimport"
$LETSMT_CONNECT -X GET "$LETSMT_URL/metadata/corpus/user/uploads/small.tar.gz?uid=user"
```
```xml
<letsmt-ws version="56">
  <list path="">
    <entry path="corpus/user/uploads/small.tar.gz">
      <gid>public</gid>
      <import_empty></import_empty>
      <import_empty_count>0</import_empty_count>
      <import_failed></import_failed>
      <import_failed_count>0</import_failed_count>
      <import_homedir>uploads/small</import_homedir>
      <import_success>en/7.html,en/2.html,en/5.html,en/1.html,en/3.html,en/4.html,en/9.html</import_success>
      <import_success_count>7</import_success_count>
      <job_id>job_1541673288_768302220</job_id>
      <owner>user</owner>
      <status>importing</status>
    </entry>
  </list>
  <status code="0" location="/metadata/corpus/user/uploads/small.tar.gz" operation="GET" type="ok">Found matching path ID. Listing all of its properties</status>
</letsmt-ws>
```


* get a list of all user jobs in the queue: Just submit a get-request without a path to job


```
$LETSMT_CONNECT -X GET "$LETSMT_URL/job?uid=user1"
```
```xml
<letsmt-ws version="55">
  <list path="jobs">
    <entry name="job_1536347840_947597648" id="60" status="PENDING" />
    <entry name="job_1536347777_876474696" id="59" status="RUNNING" />
  </list>
  <status code="0" location="job" operation="GET" type="ok" />
</letsmt-ws>
```



* `tokenize`, `parse`, `wordalign`  for specific files:

```
$LETSMT_CONNECT -X PUT "$LETSMT_URL/job/corpus/user/xml/en/4.xml?uid=user&run=tokenize"
$LETSMT_CONNECT -X PUT "$LETSMT_URL/job/corpus/user/xml/en/4.xml?uid=user&run=parse"
$LETSMT_CONNECT -X PUT "$LETSMT_URL/job/corpus/user/xml/en-sv/4.xml?uid=user&run=wordalign"
```

* `tokenize`, `parse`, `wordalign` for all files in a subtree:

```
$LETSMT_CONNECT -X PUT "$LETSMT_URL/job/opustest2/user/xml?uid=user&run=tokenize"
$LETSMT_CONNECT -X PUT "$LETSMT_URL/job/opustest2/user/xml?uid=user&run=parse"
$LETSMT_CONNECT -X PUT "$LETSMT_URL/job/corpus/user/xml/en-sv?uid=user&run=wordalign"
```



# TODO


* better use of user priveliges
* improve error reporting and status updates
