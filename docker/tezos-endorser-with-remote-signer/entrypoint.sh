#!/bin/sh

if [ "${PROTOCOL}" != "011-PtHangz2" ]; then
    while sleep 60; do
        printf "No endorser needed for protocol ${PROTOCOL}\n"
    done
else
    supervisord -n -c /etc/supervisord-tezos.conf &
    while sleep 5; do
        if [ "$(curl -s http://127.0.0.1:4040| jq -r '.name')" == "$(hostname)" ] && ! supervisorctl -c /etc/supervisord-tezos.conf status tezos-endorser > /dev/null 2>&1; then
            printf "We are now the leader, starting endorser\n"
            supervisorctl -c /etc/supervisord-tezos.conf start tezos-endorser
        elif [ "$(curl -s http://127.0.0.1:4040| jq -r '.name')" != "$(hostname)" ] && supervisorctl -c /etc/supervisord-tezos.conf status tezos-endorser > /dev/null 2>&1; then
            printf "We are no longer the leader, stopping endorser\n"
            supervisorctl -c /etc/supervisord-tezos.conf stop tezos-endorser
        fi
    done
fi
