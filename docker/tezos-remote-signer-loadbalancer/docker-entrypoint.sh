#!/bin/sh
set -e
set -x

echo "$LEDGER_PROBER_PRIVATE_KEY" > ~/.ssh/id_rsa

sudo sh -c "echo \"PUBLIC_BAKING_KEY=$PUBLIC_BAKING_KEY\" > /etc/tezos-signer-checker-params"
sudo sh -c "echo \"PROTOCOL_SHORT=$PROTOCOL_SHORT\" >> /etc/tezos-signer-checker-params"
/usr/local/bin/tezos-client -p $PROTOCOL_SHORT -d /var/run/tezos/client config init -o /var/run/tezos/client/config
echo "haproxy tezos signer load balancer is starting"
# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
	set -- haproxy "$@"
fi

if [ "$1" = 'haproxy' ]; then
	shift # "haproxy"
	# if the user wants "haproxy", let's add a couple useful flags
	#   -W  -- "master-worker mode" (similar to the old "haproxy-systemd-wrapper"; allows for reload via "SIGUSR2")
	#   -db -- disables background mode
	set -- haproxy -W -db "$@"
fi

exec "$@"
