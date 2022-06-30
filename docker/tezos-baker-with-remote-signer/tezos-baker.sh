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
accuser="$BIN_DIR/tezos-accuser-$PROTOCOL"
signer="$BIN_DIR/tezos-signer"

client_dir="$DATA_DIR/client"
node_dir="$DATA_DIR/node"
node_data_dir="$node_dir/data"

echo ${PER_BLOCK_VOTES} > ${DATA_DIR}/${BAKER_ALIAS}_per_block_votes.json
# we pass both a vote argument and a votefile argument; vote argument is mandatory as a fallback
extra_args="--liquidity-baking-toggle-vote pass --votefile ${DATA_DIR}/${BAKER_ALIAS}_per_block_votes.json"

exec "$baker" --chain main \
     --base-dir "$client_dir" \
     run with local node "$node_data_dir" ${extra_args} $BAKER_ALIAS
