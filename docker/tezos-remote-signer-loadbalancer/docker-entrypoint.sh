#!/bin/sh
set -e
set -x

envsubst < /usr/local/etc/haproxy/haproxy.cfg.template > /usr/local/etc/haproxy/haproxy.cfg
echo "haproxy tezos signer load balancer is starting"

set -- haproxy -W -db -f /usr/local/etc/haproxy/haproxy.cfg "$@"
exec "$@"
