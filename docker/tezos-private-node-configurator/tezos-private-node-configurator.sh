#!/bin/sh

set -ex

bin_dir="/usr/local/bin"

data_dir="/var/run/tezos"
node_dir="$data_dir/node"
client_dir="$data_dir/client"

printf "Writing custom configuration for private node\n"
# why hard-code this file ?
# Reason 1: we could regenerate it from scratch with cli but it requires doing tezos-node config init or tezos-node config reset, depending on whether this file is already here
# Reason 2: the --connections parameter automatically puts the number of minimal connections to half that of expected connections, resulting in logs spewing "Not enough connections (2)" all the time. Hard-coding the config file solves this.

# why not put the node in private mode ?
# The purpose of the private mode is to deny any inbound connection. Here, it is desirable to allow inbound connection from the public nodes in the same cluster, so when the public nodes start, they immediately reconnect to the private node. In private mode, we must wait for the private node to reconnect to the public node. We have observed that it can take hours and we have lost delegations because of this...
# The network policy and hard-coding of bootstrap peers below ensure that the node is effectively in private mode. It only talks to the public nodes.
rm -rvf ${node_dir}/data/config.json
mkdir -p ${node_dir}/data
cat << EOF > ${node_dir}/data/config.json
{ "data-dir": "/var/run/tezos/node/data",
  "network": "$TEZOS_NETWORK",
  "rpc": { "listen-addrs": [ ":8732", "0.0.0.0:8732" ] },
  "p2p":
    { "bootstrap-peers":
        [ "${KUBERNETES_NAME_PREFIX}-tezos-public-node-0.${KUBERNETES_NAME_PREFIX}-tezos-public-node",
          "${KUBERNETES_NAME_PREFIX}-tezos-public-node-1.${KUBERNETES_NAME_PREFIX}-tezos-public-node" ],
      "listen-addr": "[::]:9732",
      "limits":
        { "connection-timeout": 10, "min-connections": 1,
          "expected-connections": 2, "max-connections": 4,
          "max_known_points": [ 32, 24 ], "max_known_peer_ids": [ 32, 24 ] } },
  "shell": { "chain_validator": { "bootstrap_threshold": 1 } } }
EOF

cat ${node_dir}/data/config.json
