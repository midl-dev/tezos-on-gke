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

exec "$baker" --chain main \
     --base-dir "$client_dir" \
     --endpoint "http://${NODE_HOST}:${NODE_RPC_PORT}" \
     run with local node "$node_data_dir" $BAKER_ALIAS
