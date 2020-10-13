#!/bin/sh

set -e
set -x

bin_dir="/usr/local/bin"

data_dir="/var/run/tezos"
node_dir="$data_dir/node"
node_data_dir="$node_dir/data"
node="$bin_dir/tezos-node"

if [ -d ${node_dir}/data/context ]; then
    echo "Blockchain has already been imported, exiting"
    exit 0
elif [ -z "$SNAPSHOT_URL" ]; then
    echo "No snapshot was passed as parameter, exiting"
    exit 0
else
    echo "Did not find pre-existing data, importing blockchain"
    mkdir -p ${node_dir}/data
    echo '{ "version": "0.0.4" }' > ${node_dir}/version.json
    cp -v /usr/local/share/tezos/alphanet_version ${node_dir}
    snapshot_file=${node_dir}/chain.snapshot
    curl -L -o $snapshot_file $SNAPSHOT_URL
    exec "${node}" snapshot import ${snapshot_file} --data-dir ${node_data_dir} --network $TEZOS_NETWORK --config-file ${node_data_dir}/config.json
    find ${node_dir}
    rm -rvf ${snapshot_file}
fi
