# cms-vpn-tun-tap

Setup of a virtual network interface inside a singularity container using
network namespaces. All the network traffic of the container is routed to the
virtual interface and then a vpn server (ocserv). The interface gets its ip
from the vpn server.

## Pre-setup

The following is needed to allow a user to manipulate namespaces at the compute nodes:

```sh
# Add the following line to /etc/sysctl.d/99-sysctl.conf
user.max_user_namespaces=10000
```

and then run:

```sh
sysctl -p
```

The machine running the VPN host needs the following changes:

```sh
# Add the following line to /etc/sysctl.d/99-sysctl.conf
user.max_user_namespaces=10000
net.ipv4.ip_forward=1
```

and similarly run `sysctl -p` afterwards. These are the only steps that require
root at the execution sites.


## Building the containers

### Building the singularity image for the VPN clients:

```sh
$ cd context/openconnect-container
$ sudo singularity build vpncms-client.sif Singularity.def
$ cd ../..
```

The build process installs openconnect and its dependencies using the
cmssw/cms:rhel7 image as a base. It will also compile from source `vpnns`,
`ocproxy' and `tsocks`, the alternative programs to use openconnect without
root privileges.

### Building the singularity image for the VPN server:

```sh
$ cd context/ocserv-container
$ sudo singularity build vpncms-server.sif Singularity.def
$ cd ../..
```

## Running the VPN server

### Without root privileges: 

To ensure that all processes are termianted when the singularity container
terminates, we execute the image inside an instance:

```sh
$ ./launch-vpn-server --image context/ocserv-container/vpncms-server.img --instance vpn_server --add-user myvpnuser:myvpnpasswd --port 8443
Added user: myvpnuser
SERVER PIN:
pin-sha256:XXXXXXX...
```

We make note of the server pin printed, as we will need it when connecting the clients.


### With root privileges: 

$ sudo ./launch-vpn-server --image vpncms-server.img --instance vpn_server --add-user myvpnuser:myvpnpasswd --port 8443 --privileged


## Launch some vpn clients;
```sh
$ ./launch-vpn-client --image vpncms-client.sif \
     --server MACHINE_WHERE_OCSERV_RUNS:8443 \
     --servercert pin-sha256:XXXXXXX... \
     --user myvpnuser \
     --passwd myvpnpasswd \
     --vpn-mode ns \
     -- /bin/bash
```

The `launch-vpn-client` script simply starts/stops an instance of the singularity
container so that no openconnect services are left behind The real virtual interface
setup magic happens in /etc/cms-vpn/vpn-start.sh.

## Adding cvmfs support

cvmfs can be provided using cvmfsexec via fusermount and singularity. We do
this by creating a self-contained cvmfsexec distribution and using it as the
singularity executable:

```
$ git clone https://github.com/cvmfs/cvmfsexec.git
$ cd cvmfsexec
$ ./makedist -s -m rhel7-x86_64 osg
$ ./makedist -s -o /tmp/singularity-cmvfsexec
$ cd ..
$ export SINGCVMFS_REPOSITORIES=cms.cern.ch,atlas.cern.ch,oasis.opensciencegrid.org
$ ./launch-vpn-client --image vpncms-client.sif \
     --server MACHINE_WHERE_OCSERV_RUNS:8443 \
     --servercert pin-sha256:XXXXXXX... \
     --user myvpnuser \
     --passwd myvpnpasswd \
     --vpn-mode ns \
     --singularity /tmp/singularity-cmvfsexec \
     -- ls /cvmfs/cms.cern.ch
```

