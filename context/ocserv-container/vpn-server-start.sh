#! /bin/bash

set -e

source /etc/cms-vpn/vpn-common.sh

# default options for ocserv.conf
ocserv_conf_template=/etc/ocserv/ocserv.conf.template
ocserv_conf_masq_template=/etc/ocserv/vpn-iptables.template
ocserv_conf_port=${VPN_PORT:-8443}
ocserv_conf_default_domain=ocserv-server.net
ocserv_conf_rx_bytes_sec=${VPN_RX_LIMIT:-1250000000}
ocserv_conf_tx_bytes_sec=${VPN_TX_LIMIT:-1250000000}

ocserv_files=/srv/ocserv-files
ocserv_etc=${ocserv_files}/etc

ocserv_conf_file=${ocserv_etc}/ocserv.conf
ocserv_conf_masq_file=${ocserv_etc}/vpn-iptables
ocserv_conf_passwd=${ocserv_etc}/ocserv.passwd
ocserv_conf_certs="${ocserv_etc}"/certs
ocserv_conf_pool=${VPN_POOL}
ocserv_conf_dns="${VPN_DNS}"

VPN_PRIVILEGED=${VPN_PRIVILEGED:-no}

if [[ "${VPN_PRIVILEGED}" = no ]]
then
    ocserv_conf_gateway=10.0.2.0/24             # default value from slirp4netns for tap0
    ocserv_conf_interface=tap0
else
    ocserv_conf_gateway=default                 # default for ocserv
    ocserv_conf_interface=eth0
fi


trap cleanup EXIT
cleanup () {
    if [[ -f "${ns_pid}" ]]
    then
        kill $(cat ${ns_pid}) && rm -f "${ns_pid}"
    fi

    if [[ -f "${slirp_pid}" ]]
    then
        kill $(cat ${slirp_pid}) && rm -f "${slirp_pid}"
    fi

    if [[ -e "${CUSTOM_NAMESPACE}" ]]
    then
        umount "${CUSTOM_NAMESPACE}"
    fi
}


write_conf_files () {
    # Turn comma-separated into dns=...\ndns=...
    ocserv_conf_dns=$(echo dns=${ocserv_conf_dns} | sed -E 's/,/\ndns=/g')

    # write ocserv.conf
    template="$(cat ${ocserv_conf_template})"
    eval "echo \"${template}\"" > "${ocserv_conf_file}"

    template="$(cat ${ocserv_conf_masq_template})"
    eval "echo \"${template}\"" > "${ocserv_conf_masq_file}"
}

if ! mkdir -p "${ocserv_files}"/{etc,run}
then
    echo "Could not create working directory: $ocserv_files"
    exit 1
fi

ns_pid=/srv/ocserv-files/run/ns_pid.$$
slirp_pid=/srv/ocserv-files/run/slirp_pid.$$
slirp_socket=/srv/ocserv-files/run/slirp.socket.$$
ocserv_pid=/srv/ocserv-files/run/ocserv.pid    # comes from ocserv.conf

# copy pre-defined user and passwords if available
if [[ ! -f "$ocserv_conf_passwd" ]] && [[ -f /etc/ocserv/ocserv.passwd ]]
then
   cp /etc/ocserv/ocserv.passwd "${ocserv_conf_passwd}"
fi

if [[ -n "${VPN_NEW_USER}" ]]
then
    user=${VPN_NEW_USER%%:*}
    pass=${VPN_NEW_USER##*:}

    if [[ -z "${user}" ]] || [[ -z "${pass}" ]]
    then
        echo "New user specification should be of the form USER:PASS"
        exit 1
    fi

    if echo "${pass}" | ocpasswd -c "${ocserv_conf_passwd}" "${user}"
    then
        echo "Added user: ${user}"
    else
        echo "Failed to add user: ${user}"
        exit 1
    fi
fi

# Whether to create a network namespace for the network interface
if [[ "${VPN_PRIVILEGED}" = no ]]
then
    net_option="--net"
fi

write_conf_files

# Create the namespace where ocserv will run
unshare --user --map-root-user ${net_option} --mount /bin/sh <<EOF &
source /etc/cms-vpn/vpn-common.sh

mount --bind /etc/ocserv/resolv.conf /etc/resolv.conf
mount --bind /etc/ocserv/hosts.allow /etc/hosts.allow
mount --bind /etc/ocserv/hosts.deny  /etc/hosts.deny

if [[ "${VPN_PRIVILEGED}" = no ]]
then
    # waiting for slirp4netns to create the interface
    wait_for_event 5 ip addr show ${ocserv_conf_interface}
fi

# setup masquerading defautls
iptables-restore < ${ocserv_conf_masq_file}
iptables -A INPUT -p tcp --dport ${ocserv_conf_port} -j ACCEPT
iptables -A INPUT -p udp --dport ${ocserv_conf_port} -j ACCEPT

#launch ocserv
export LD_PRELOAD=/usr/lib/keep_privileges.so

# generate certificates
/usr/bin/ocserv-genkey ${ocserv_conf_certs}

ocserv -f -c ${ocserv_conf_file}
EOF
echo $! > ${ns_pid}

# Create tap0 if necessary
if [[ "${VPN_PRIVILEGED}" = no ]]
then
    # Create virtual network interface in the namespace (tap0)
    slirp4netns --configure --mtu=65520 --disable-host-loopback $(cat ${ns_pid}) -a ${slirp_socket} tap0 &
    echo $! > ${slirp_pid}
    wait_for_event 5 stat ${slirp_socket}

    # Expose port $ocserv_conf_port. $ocserv_conf_port is used for incoming vpn client connections
    json_api='{"execute": "add_hostfwd", "arguments": {"proto": "tcp", "host_addr": "0.0.0.0", "host_port": '"${ocserv_conf_port}"', "guest_addr": "10.0.2.100", "guest_port": '"${ocserv_conf_port}"'}}'
    echo "${json_api}" | nc -U ${slirp_socket}
fi

wait

