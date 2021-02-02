#! /bin/bash

SOCKS_PORT=${SOCKS_PORT:-11080}
NET_MODE=${NET_MODE:-auto}

trap cleanup EXIT
cleanup () {
    if [[ -f "${TSOCKS_CONF}" ]]
    then
        rm -f "${TSOCKS_CONF}"
    fi
}

if [[ "${NET_MODE}" = auto || "${NET_MODE}" = ns ]]
then
    if echo  supersecretpassword | openconnect ${VPN_SERVER} -u vpnuser --servercert ${SERVERPIN} -b --passwd-on-stdin --script-tun  --script "vpnns --attach"
    then
        sleep 1
        echo "Using virtual network interface..."
        vpnns "$@"
        status=$?
        exit $?
    fi
fi

# fallback to socks
if [[ "${NET_MODE}" = auto || "${NET_MODE}" = socks ]]
then
    echo supersecretpassword | openconnect ${VPN_SERVER} -u vpnuser --servercert ${SERVERPIN} -b --passwd-on-stdin --script-tun --script "/usr/bin/ocproxy -D${SOCKS_PORT}"
    export LD_PRELOAD=/lib/libtsocks.so.1.8 

    export TSOCKS_CONF=$(readlink -m $(mktemp -p ${SIN_HOME} tsocks.conf.XXXXXX))
    cat >> ${TSOCKS_CONF} <<EOF
server = 127.0.0.1
server_type = 5
server_port = ${SOCKS_PORT}
EOF

    echo "Using socks5 server..."
    "$@"
    status=$?
    exit $?
fi

echo "Could not start vpn connection."

