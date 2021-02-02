# cms-openconnect-tun

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


1. Build singularity image:

```sh
$ cd context
$ sudo singularity build vpncms.sif Singularity.def
```

The build process will compile `vpnns` for the cmssw/cms:rhel6 base docker
image. It also copies a test configuration for the ocserv vpn server with a
default password (thus do not use this in production!).

2. Run the ocserv vpn server. This needs to be run as root, since we need to
   setup some iptables.

```sh
$ LAUNCH_VPN_SERVER=yes sudo singularity run vpn-overlay vpncms.sif
### start vpn server with some debug output and in the foreground:
$ ocserv -f -d99
```

If using docker for the vpn server, it needs to run in separate network than
`host`, e.g.:

```sh
$ docker network create vpncms-net
$ docker run -e LAUNCH_VPN_SERVER=yes --rm --name oscserv -ti -p 9443:9443 --privileged --network vpncms-net  -v $(pwd):/srv vpncms /bin/bash
```

3. Launch some clients. They do not need to be run as root.
```sh
./launch_instance --image vpncms.sif --vpn-server MACHINE_WHERE_OCSERV_RUNS:9443 -- /bin/bash
```

The `launch_instance` script simply starts/stops an instance of the singularity
container so that no openconnect services are left behind The real virtual interface
setup magic happens in /etc/vpn_start.sh.

4. Adding cvmfs support

cvmfs can be provided using cvmfsexec via fusermount and singularity.

Create a singularity distribution of cvmfsexec (`-s` command line option) and
set `--singularity` of `launch_instance` to the resulting cvmfsexec file. [NEED
TO EXPAND.]

5. Debugging:
```sh
$ ./launch_instance --start-net no --image vpncms.sif --vpn-server MACHINE_WHERE_OCSERV_RUNS:9443 -- /bin/bash
...
$ ip addr
Singularity> ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN qlen 1000
link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
inet 127.0.0.1/8 scope host lo
valid_lft forever preferred_lft forever
inet6 ::1/128 scope host 
valid_lft forever preferred_lft forever
2: enp0s25: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc pfifo_fast state DOWN qlen 1000
...

$ /etc/vpn_start.sh /bin/bash
$ ip addr
Singularity> ifconfig 
lo        Link encap:Local Loopback  
inet addr:127.0.0.1  Mask:255.0.0.0
inet6 addr: ::1/128 Scope:Host
...

tun0      Link encap:UNSPEC  HWaddr 00-00-00-00-00-00-00-00-00-00-00-00-00-00-00-00  
inet addr:192.168.1.23  P-t-P:192.168.1.23  Mask:255.255.255.255
inet6 addr: fe80::9c62:1dca:32f6:3619/64 Scope:Link
UP POINTOPOINT RUNNING NOARP MULTICAST  MTU:1472  Metric:1
...
```


