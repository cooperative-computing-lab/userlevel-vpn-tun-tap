# cms-vpn-tun-tap

Setup of a virtual network interface inside a singularity container using
network namespaces. All the network traffic of the container is routed to the
virtual interface and then a vpn server (ocserv). The interface gets its ip
from the vpn server.

0. Pre-setup

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


1. Building the containers

1.1 Building the singularity image for the VPN clients:

```sh
$ cd context/openconnect-container
$ sudo singularity build vpncms-client.sif Singularity.def
```

The build process installs openconnect and its dependencies using the
cmssw/cms:rhel7 image as a base. It will also compile from source `vpnns`,
`ocproxy' and `tsocks`, the alternative programs to use openconnect without
root privileges.

1.2 Building the singularity image for the VPN server:

```sh
$ cd context/ocserv-container
$ sudo singularity build vpncms-server.sif Singularity.def
```

2. Running the VPN server

2.a Without root privileges: 

To ensure that all processes are termianted when the singularity container
terminates, we execute the image inside an instance:

```sh
$ singularity instance start --home $(pwd):/srv vpncms-server.sif my-vpnserver-instance
$ singularity run --home $(pwd):/srv instance://my-vpnserver-instance
# inside the container:
$ /usr/bin/launch_ocserv --add-user myvpnuser:myvpnpasswd --port 8443
Added user: myvpnuser
SERVER PIN:
pin-sha256:XXXXXXX...
```

We make note of the server pin printed, as we will need it when connecting the clients.


2.b With root privileges: 

[[ something similar to the above; but using singularity --network, etc. need to expand ]]


2.c Docker [[ obsolete instructions, need to update ]]

If using docker for the vpn server, it needs to run in separate network than
`host`, e.g.:

```sh
$ docker network create vpncms-net
$ docker run -e LAUNCH_VPN_SERVER=yes --rm --name oscserv -ti -p 9443:9443 --privileged --network vpncms-net  -v $(pwd):/srv vpncms /bin/bash
```

3. Launch some vpn clients;
```sh
$ ./launch-vpn-client --image vpncms-client.sif \
     --server MACHINE_WHERE_OCSERV_RUNS:8443 \
     --servercert pin-sha256:XXXXXXX... \
     --user myvpnuser \
     --passwd myvpnpasswd \
     --net-mode ns \
     -- /bin/bash
```

The `launch-vpn-client` script simply starts/stops an instance of the singularity
container so that no openconnect services are left behind The real virtual interface
setup magic happens in /etc/cms-vpn/vpn-start.sh.

4. Adding cvmfs support

cvmfs can be provided using cvmfsexec via fusermount and singularity.

Create a singularity distribution of cvmfsexec (`-s` command line option) and
set `--singularity` of `launch-vpn-client` to the resulting cvmfsexec file. [NEED
TO EXPAND.]

