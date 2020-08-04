#!/bin/sh
set -e
set -x

if [ ! -z $SIGNER_A_KEY ]; then
    SIGNER_A_LINE="server tezos-signer-1 xta-tezos-remote-signer-forwarder:${SIGNER_A_PORT} check inter 15000"
fi
if [ ! -z $SIGNER_A_KEY ]; then
    SIGNER_B_LINE="server tezos-signer-2 xta-tezos-remote-signer-forwarder:${SIGNER_B_PORT} check inter 15000"
fi
envsubst < /usr/local/etc/haproxy/haproxy.cfg.template > /usr/local/etc/haproxy/haproxy.cfg
echo "haproxy tezos signer load balancer is starting"

set -- haproxy -W -db -f /usr/local/etc/haproxy/haproxy.cfg "$@"
exec "$@"
