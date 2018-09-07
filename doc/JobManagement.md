
# Batch job management

Since version 0.56 we now use SLURM as the default job management. This is much easier to set up and seems to be more robust as well. Forget about SGE and don't try to install the old gridengine anymore!


Jobs are submitted for importing and aligning documents and they are triggered either from the `job` API or automatically after a new upload to storage with the `action=import` flag added. Look at [importing files](ImportingFiles.md) for details.


# New in the Job API


* get a list of all jobs in the queue: Just submit a get-request without a path to job


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

TODO: Should we require the `admin` user for that? How do we find the actual job that is queued and the user who submitted the job? Search in metadata for the Job ID?