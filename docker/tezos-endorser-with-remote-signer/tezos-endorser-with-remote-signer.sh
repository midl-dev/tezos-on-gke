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

. "$BIN_DIR/entrypoint.inc.sh"

wait_for_the_node_to_be_bootstraped
exec "$endorser" --chain main \
     --base-dir "$client_dir" \
     --addr "$NODE_HOST" --port "$NODE_RPC_PORT" \
     -R "http://tezos-remote-signer-forwarder:8443/$PUBLIC_BAKING_KEY" \
     run "$@"
