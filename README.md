# cms-openconnect-tun

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

3. Launch some clients. They do not need to be run as root.
```sh
./launch_instance --image vpncms.sif --vpn-server MACHINE_WHERE_OCSERV_RUNS:9443 -- /bin/bash
```

The `launch_instance` script simply starts/stops an instance of the singularity
container so that no openconnect services are left behind The real virtual interface
setup magic happens in /etc/vpn_start.sh.

4. Debugging:
```sh
./launch_instance --start-net no --image vpncms.sif --vpn-server MACHINE_WHERE_OCSERV_RUNS:9443 -- /bin/bash
...
/etc/vpn_start.sh /bin/bash
```


