#!/bin/sh

set -e

bin_dir="/usr/local/bin"

data_dir="/var/run/tezos"
node_dir="$data_dir/node"
node_data_dir="$node_dir/data"
node="$bin_dir/tezos-node"

if [ -d ${node_dir}/data/context ]; then
    echo "Blockchain has already been imported, exiting"
    exit 0
else
    echo "Did not find pre-existing data, importing blockchain"
    rm -rvf ${node_dir}/*
    mkdir ${node_dir}/data
    echo '{ "version": "0.0.4" }' > ${node_dir}/version.json
    cp -v /usr/local/share/tezos/alphanet_version ${node_dir}
    snapshot=$(echo -n "$@")
    snapshot_file=${node_dir}/chain.snapshot
    curl -s https://api.github.com/repos/Phlogi/tezos-snapshots/releases/latest | jq -r ".assets[] | select(.name) | .browser_download_url" | grep roll | xargs wget -q
    cat mainnet.roll.* | xz -d -v -T0 > $snapshot_file
    exec "${node}" snapshot import ${snapshot_file} --data-dir ${node_data_dir}
    find ${node_dir}
    rm -rvf ${snapshot_file}
fi
