#!/bin/sh

set -e

BIN_DIR="/usr/local/bin"

: ${DATA_DIR:="/var/run/tezos"}

: ${NODE_HOST:="node"}
: ${NODE_RPC_PORT:="8732"}

: ${PROTOCOL:="unspecified-PROTOCOL-variable"}

node="$BIN_DIR/tezos-node"
client="$BIN_DIR/tezos-client"
admin_client="$BIN_DIR/tezos-admin-client"
baker="$BIN_DIR/tezos-baker-$PROTOCOL"
endorser="$BIN_DIR/tezos-endorser-$PROTOCOL"
accuser="$BIN_DIR/tezos-accuser-$PROTOCOL"
signer="$BIN_DIR/tezos-signer"

client_dir="$DATA_DIR/client"
node_dir="$DATA_DIR/node"
node_data_dir="$node_dir/data"

wait_for_the_node_to_be_ready() {
    local count=0
    if "$client" rpc get /chains/main/blocks/head/hash >/dev/null 2>&1; then return; fi
    printf "Waiting for the node to initialize..."
    sleep 1
    while ! "$client" rpc get /chains/main/blocks/head/hash >/dev/null 2>&1
    do
        count=$((count+1))
        if [ "$count" -ge 30 ]; then
            echo " timeout."
            exit 2
        fi
        printf "."
        sleep 1
    done
    echo " done."
}

wait_for_the_node_to_be_bootstrapped() {
    wait_for_the_node_to_be_ready
    echo "Waiting for the node to synchronize with the network..."
    "$client" bootstrapped
}

wait_for_the_node_to_be_bootstrapped

exec "$baker" --chain main \
     --base-dir "$client_dir" \
     --addr "$NODE_HOST" --port "$NODE_RPC_PORT" \
     run with local node "$node_data_dir" $BAKER_ALIAS
