#!/bin/sh

set -e

bin_dir="/usr/local/bin"

data_dir="/var/run/tezos"
node_dir="$data_dir/node"
client_dir="$data_dir/client"

if [ -d ${node_dir}/data/context ]; then
    echo "Blockchain has already been imported, skipping"
else
    echo "Did not find pre-existing data, importing blockchain"
    rm -rvf ${node_dir}/*
    mkdir ${node_dir}/data
    echo '{ "version": "0.0.3" }' > ${node_dir}/version.json
    echo '{ "version": "0.0.3" }' > ${node_dir}/data/version.json
    cp -v /usr/local/share/tezos/alphanet_version ${node_dir}
    snapshot=$(echo -n "$@")
    echo "Will download $snapshot"
    curl -L $snapshot | lz4 -d | tar -xvf - -C ${node_dir}/data
    find ${node_dir}
fi

if [ -z "$PUBLIC_BAKING_KEY" ]; then
    echo "No public key to import, skipping"
elif grep $PUBLIC_BAKING_KEY $client_dir/public_key_hashs; then
    echo "Public key already imported, skipping"
else
    echo "Importing public key http://tezos-remote-signer:8445/$PUBLIC_BAKING_KEY"
    exec "${bin_dir}/tezos-client" --base_dir $client_dir -p $PROTOCOL_SHORT import secret key k8s-baker http://tezos-remote-signer:8445/$PUBLIC_BAKING_KEY -f
fi
