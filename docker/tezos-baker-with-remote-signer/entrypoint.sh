#!/bin/sh

supervisord -n -c /etc/supervisord-tezos.conf &

while sleep 5; do
    if [ "$(curl -s http://localhost:4040| jq -r '.name')" == "$(hostname)" ] && ! supervisorctl -c /etc/supervisord-tezos.conf status tezos-baker > /dev/null 2>&1; then
        printf "We are now the leader, starting baker\n"
        supervisorctl -c /etc/supervisord-tezos.conf start tezos-baker
    elif [ "$(curl -s http://localhost:4040| jq -r '.name')" != "$(hostname)" ] && supervisorctl -c /etc/supervisord-tezos.conf status tezos-baker > /dev/null 2>&1; then
        printf "We are no lonnger the leader, stopping baker\n"
        supervisorctl -c /etc/supervisord-tezos.conf stop tezos-baker
    fi
done
