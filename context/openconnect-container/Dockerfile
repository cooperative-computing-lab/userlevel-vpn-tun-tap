# DOCKER_BUILDKIT=1  docker build -t cmsopenconnect context

FROM cmssw/cms:rhel6
RUN yum install -y openconnect ocserv ufw libevent2

#http://rdo.fedorapeople.org/rdo-release.rpm kernel iproute

# sets DEFAULT_FORWARD_POLICY="ACCEPT"
COPY ufw /etc/default/ufw

# NAT rule outside<->vpn<->client
COPY before.rules /etc/ufw/before.rules

COPY entry_point.sh vpn_start.sh /etc/

COPY ocproxy vpnns /usr/bin/
COPY ocserv.conf ocserv.passwd /etc/ocserv/

COPY tsocks.conf /etc/
COPY ./tsocks/tsocks tsocks/inspectsocks tsocks/saveme tsocks/validateconf /usr/bin/
COPY ./tsocks/libtsocks.so tsocks/libtsocks.so.1.8 /lib/


ENTRYPOINT /etc/entry_point.sh

