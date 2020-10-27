#! /bin/bash

DPORT=${DPORT:-11080}
NET_MODE=${NET_MODE:-auto}

if [[ "${NET_MODE}" = auto || "${NET_MODE}" = ns ]]
then
    if echo  supersecretpassword | openconnect ${VPN_SERVER} -u vpnuser --no-cert-check -b --passwd-on-stdin --no-dtls --script-tun  --script "vpnns --attach"
    then
        sleep 1
        echo "Using virtual network interface..."
        vpnns "$@"
        exit 0
    fi
fi

# fallback to socks
if [[ "${NET_MODE}" = auto || "${NET_MODE}" = socks ]]
then
    echo supersecretpassword | openconnect ${VPN_SERVER} -u vpnuser --no-cert-check -b --passwd-on-stdin --no-dtls --script-tun --script "/usr/bin/ocproxy -D${DPORT}"
    export LD_PRELOAD=/lib/libtsocks.so.1.8 

    echo "Using socks5 server..."
    exec "$@"
fi

echo "Could not start vpn connection."

