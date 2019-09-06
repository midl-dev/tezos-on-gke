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
    echo "{ "version": "0.0.3" }" > ${node_dir}/version.json
    snapshot=$(echo -n "$@")
    echo "Will download $snapshot"
    wget "$snapshot" -O ${node_dir}/chain.full
    sh ${bin_dir}/entrypoint.sh tezos-snapshot-import ${node_dir}/chain.full
    find ${node_dir}
    rm -rvf ${node_dir}/chain.full
fi
