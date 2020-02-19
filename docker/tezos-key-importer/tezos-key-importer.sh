#!/bin/sh

set -e

bin_dir="/usr/local/bin"

data_dir="/var/run/tezos"
node_dir="$data_dir/node"
client_dir="$data_dir/client"

if [ -z "$PUBLIC_BAKING_KEY" ]; then
    echo "No public key to import, skipping"
elif grep $PUBLIC_BAKING_KEY $client_dir/public_key_hashs; then
    echo "Public key already imported, skipping"
else
    echo "Importing public key http://tezos-remote-signer:8445/$PUBLIC_BAKING_KEY"
    exec "${bin_dir}/tezos-client" --base_dir $client_dir -p $PROTOCOL_SHORT import secret key k8s-baker http://tezos-remote-signer:8445/$PUBLIC_BAKING_KEY -f
fi
