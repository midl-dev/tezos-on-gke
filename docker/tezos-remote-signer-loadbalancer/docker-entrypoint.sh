#!/bin/sh
set -e
set -x

urlencode() {
    # urlencode <string>
    old_lc_collate=$LC_COLLATE
    LC_COLLATE=C
    local i=1
    local length="${#1}"
    while [ $i -le $length ]
    do
        local c=$(echo "$(expr substr $1 $i 1)")
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            ' ') printf "%%20" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
        i=`expr $i + 1`
    done

    LC_COLLATE=$old_lc_collate
}

if [ ! -z $SIGNER_A_PORT ]; then
    export SIGNER_A_LINE="server tezos-signer-1 127.0.0.1:${SIGNER_A_PORT} check inter 15000"
fi
if [ ! -z $SIGNER_B_PORT ]; then
    export SIGNER_B_LINE="server tezos-signer-2 127.0.0.1:${SIGNER_B_PORT} check inter 15000"
fi

export LEDGER_AUTHORIZED_PATH_ENCODED=$(urlencode $LEDGER_AUTHORIZED_PATH)
if [ "${RPI_SIGNER}" == "false" ]; then
  export HTTP_CHK_ADDRESS="/authorized_keys"
else
  export HTTP_CHK_ADDRESS="/statusz/${PUBLIC_BAKING_KEY_HASH}?ledger_url=${LEDGER_AUTHORIZED_PATH_ENCODED}"
fi

envsubst < /usr/local/etc/haproxy/haproxy.cfg.template > /usr/local/etc/haproxy/haproxy.cfg
echo "haproxy tezos signer load balancer is starting"

set -- haproxy -W -db -f /usr/local/etc/haproxy/haproxy.cfg "$@"
exec "$@"
