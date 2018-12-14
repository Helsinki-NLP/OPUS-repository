
# OPUS resource repository

## Install the OPUS repository server

* launch a new instance from cPouta with Ubuntu 14.04 and the opus access key
* make sure that ssh, default and web are enabled as access groups
* attach the instance to a floating IP (for example `vm0081.kaj.pouta.csc.fi`)
* login on the new instance and download the repository software

```
sudo apt-get install git
git clone https://github.com/Helsinki-NLP/LetsMT-repository.git
```

* install the software

```
export HOSTNAME=vm0081.kaj.pouta.csc.fi
sudo make install-opus
```


## Install compute nodes

* launch a new instance from cPouta with Ubuntu 14.04 and the opus access key
* make sure that ssh, default and web are enabled as access groups
* login on the new instance and download the repository software

```
sudo apt-get install git
git clone https://github.com/Helsinki-NLP/LetsMT-repository.git
```

* install the software (adjust OPUSRR and OPUSIP if necessary)

```
sudo make opus-client
```

* add the new node to SLURM controler running on the repository server
* add the IP address to `/etc/hosts` (assuming the hostname of the new node is `opus-node0` and the IP is `192.168.1.13`)

```
192.168.1.13    opus-node0.novalocal    opus-node0
```

* add the node to the slurm configuration in `/etc/slurm-llnl/slurm.conf`

```
NodeName=opus-node0 CPUs=1 State=UNKNOWN
PartitionName=debug Nodes=opus-rr,opus-node0 Default=YES MaxTime=2880 State=UP
```


## Install stable version

Add `-stable` to the make targets (this should also be the default of `make install-opus` and `make install-opus-client`):

```
make opus-stable
make opus-client-stable
```


## Install development version

Add `-dev` to the make targets:

```
make opus-dev
make opus-client-dev
```


## Updating the system

* pull latest source from git on all servers (including compute nodes)
* run the make commands as above on all nodes
* make sure that slurm is running corectly with connections to all nodes (`sinfo`)