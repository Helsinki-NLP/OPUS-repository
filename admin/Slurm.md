
# Using SLURM for job management

## Configuration

The slurm configuration is in `/etc/slurm-llnl/slurm.conf`. More about the SLURM scheduler software is available here: https://slurm.schedmd.com. For administrattion: https://slurm.schedmd.com/quickstart_admin.html.

* adjusting the number of CPUs that can be allocated in a node (also controls the number of single-threaded tasks to be scheduled): change the CPUs attribute in the NodeName line of `/etc/slurm-llnl/slurm.conf`, for example to set 2 CPUs for a node called letsmt

```
NodeName=opus-rr CPUs=2 State=UNKNOWN
```

## Adding nodes to SLURM

See also https://bitsanddragons.wordpress.com/2016/09/02/adding-nodes-to-slurm/

* start a new machine (e.g. node110) and install the repository client software; make sure that you enter the correct hostname of the main repository server

```
ssh node110
git clone https://github.com/Helsinki-NLP/LetsMT-repository.git
cd LetsMT-repository
make install-client
```

* install slurm and copy ssl keys from the main repository server

```
scp -r etc/ssl cloud-user@node110:ssl-keys
ssh node110
sudo cp -R ssl-keys /etc/ssl
```

* make sure that slurm/munge users are the same and that you can munge/remunge from login node

```
id munge
id slurm
munge -n | ssh node110 unmunge
```

* change slurm configuration on compute node node110 `/etc/slurm-llnl/slurm.conf`; set ControlMachine (main repository server name, e.g. `opus-rr`) and compute nodes:

```
ControlMachine=opus-rr
...
NodeName=opus-rr CPUs=2 State=UNKNOWN
NodeName=node110 CPUs=1 State=UNKNOWN
PartitionName=debug Nodes=opus-rr,node110 Default=YES MaxTime=2880 State=UP
```

* add host information in `/etc/hosts` by adding a line for the main repository server

```
xxx.xxx.x.xx    opus-rr.domain.org    opus-rr
```

* restart slurm server (and munge?)

```
sudo service munge restart
sudo service slurm-llnl restart
```

* add the compute node name in the slurm config on the main repository server and also add the host inoformation about the new node in `/etc/hosts` and restart slurm, munge (and possibly even the webserver)

* modify the state with scontrol, specifying the node and the new state. You must provide a reason when disabling a node.

```
Disable: scontrol update NodeName=node[02-04] State=DRAIN Reason=”Cloning”
Enable: scontrol update NodeName=node[02-04] State=RESUME
```

* TODO

Can we automatize this and can we do that without interrupting the service?


## Troubleshooting

If the compute nodes and controller don't find each other: make sure that ssh-agent is running. Try:

```
eval $(ssh-agent -s)
```

resume a node that seems to be down but running OK:

```
sudo scontrol update NodeName=opus-node0 State=RESUME
```

show status of a node:

```
scontrol show node opus-node0
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