#! /bin/bash

VPN_SERVER=${VPN_SERVER:-cclws16.cse.nd.edu:9443}
START_NET=${START_NET:-yes}

if [[ "${START_NET}" = no ]]
then
    exec "$@"
fi


if [[ "${LAUNCH_VPN_SERVER}" = yes ]]
then
    ocserv-genkey
    ufw enable
    ufw allow 9443
    exec /bin/bash
else
    echo "Activating openconnect..."
    /etc/vpn_start.sh "$@"
fi

