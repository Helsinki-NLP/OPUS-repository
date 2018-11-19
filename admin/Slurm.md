
# Using SLURM for job management

## Configuration

The slurm configuration is in `/etc/slurm-llnl/slurm.conf`. More about the SLURM scheduler software is available here: https://slurm.schedmd.com. For administrattion: https://slurm.schedmd.com/quickstart_admin.html.

* adjusting the number of CPUs that can be allocated in a node (also controls the number of single-threaded tasks to be scheduled): change the CPUs attribute in the NodeName line of `/etc/slurm-llnl/slurm.conf`, for example to set 2 CPUs for a node called letsmt

```
NodeName=opus-rr CPUs=2 State=UNKNOWN
```





## Setting up SLURM (now done automatically from `make install`)

* SLURM is now default in the repository software! The information below is just for keeping the info about its setup. It should be installed without problems from the standard installation routines.

```
sudo apt-get install slurm-llnl
sudo apt-get install munge
sudo /usr/sbin/create-munge-key
sudo service munge start
sudo echo 'CgroupAutomount=yes' > /etc/slurm-llnl/cgroup.conf
```

* Create `/etc/slurm-llnl/slurm.conf` (use configuration generator at https://slurm.schedmd.com/configurator.html). 
* My current config file:


```
ControlMachine=letsmt
AuthType=auth/munge
CryptoType=crypto/munge
MpiDefault=none
ProctrackType=proctrack/cgroup
ReturnToService=1
SlurmctldPidFile=/var/run/slurmctld.pid
SlurmctldPort=6817
SlurmdPidFile=/var/run/slurmd.pid
SlurmdPort=6818
SlurmdSpoolDir=/var/spool/slurmd
SlurmUser=root
StateSaveLocation=/var/spool/slurm.state
SwitchType=switch/none
TaskPlugin=task/affinity
TaskPluginParam=Sched
InactiveLimit=0
KillWait=30
MinJobAge=300
SlurmctldTimeout=120
SlurmdTimeout=300
Waittime=0
FastSchedule=1
SchedulerType=sched/backfill
SelectType=select/cons_res
SelectTypeParameters=CR_Core
AccountingStorageType=accounting_storage/none
AccountingStoreJobComment=YES
ClusterName=cluster
JobCompType=jobcomp/none
JobAcctGatherFrequency=30
JobAcctGatherType=jobacct_gather/none
SlurmctldDebug=3
SlurmdDebug=3
NodeName=opus-rr CPUs=1 State=UNKNOWN
PartitionName=debug Nodes=letsmt Default=YES MaxTime=2880 State=UP
```

* start slurm daemons:

```
sudo service slurm-llnl start
```

* related info: https://www.invik.xyz/work/Slurm-on-Ubuntu-Trusty/
* if this fails: run on command line with verbose output

```
sudo slurmctld -Dvvv
sudo slurmd -Dvvv
```