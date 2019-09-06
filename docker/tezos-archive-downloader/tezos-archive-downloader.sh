#!/bin/sh

set -e

bin_dir="/usr/local/bin"

data_dir="/var/run/tezos"
node_dir="$data_dir/node"

if [ -d ${node_dir}/data/context ]; then
    echo "Blockchain has already been imported, exiting"
    exit 0
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
