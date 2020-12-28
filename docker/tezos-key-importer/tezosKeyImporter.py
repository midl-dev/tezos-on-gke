#!/usr/local/bin/python

import glob
import json
import os
from pathlib import Path

signer_data = json.loads(os.environ["SIGNER_DATA"])
KUBERNETES_NAME_PREFIX = os.environ["KUBERNETES_NAME_PREFIX"]
CLIENT_DIR = '/var/run/tezos/client'

# python objects that will become the tezos-client key configuration
# insead of using the tezos command, we are writing to the client config files directly. why?
# because the tezos-client import secret key command talks to the remote signer prior to adding the key in its internal state.
# so it means, unless the signer is ready, the tezos-node won't start. that's not ok.
public_keys = []
public_key_hashs = []
secret_keys = []
for node_key, node_val in signer_data["baking_nodes"].items():
    for baker_key, baker_val in node_val.items():
        public_key_hashs.append(
                { "name" : "k8s-baker-%s" % baker_key, 
                  "value" : baker_val["public_baking_key_hash"] })
        if "authorized_signers" in baker_val:
            remote_signer_url = "http://%s-tezos-remote-signer-loadbalancer-%s:8445/%s" % ( KUBERNETES_NAME_PREFIX, baker_key, baker_val["public_baking_key_hash"] )
            public_keys.append(
                { "name" : "k8s-baker-%s" % baker_key, 
                  "value" : {
                    "locator": remote_signer_url,
                    "key": baker_val["public_baking_key"]}})
            secret_keys.append(
                { "name" : "k8s-baker-%s" % baker_key, 
                  "value": remote_signer_url })
        else:
            secret_keys.append(
                { "name" : "k8s-baker-%s" % baker_key, 
                  "value" : "unencrypted:%s" % baker_val["insecure_private_baking_key"]  })
            public_keys.append(
                { "name" : "k8s-baker-%s" % baker_key, 
                  "value" : {
                    "locator": "unencrypted:%s" % baker_val["public_baking_key"],
                    "key": baker_val["public_baking_key"]}})


if __name__ == "__main__":
    Path(CLIENT_DIR).mkdir(exist_ok=True)
    print(f"Importing Tezos keys by writing into {CLIENT_DIR}")
    print("************public_keys***************")
    print(json.dumps(public_keys, indent = 2))
    print("************public_key_hashs**********")
    print(json.dumps(public_key_hashs, indent = 2))
    print(json.dumps(public_keys, indent = 2), file=open('%s/public_keys' % CLIENT_DIR, 'w'))
    print(json.dumps(public_key_hashs, indent = 2), file=open('%s/public_key_hashs' % CLIENT_DIR, 'w'))
    print(json.dumps(secret_keys, indent = 2), file=open('%s/secret_keys' % CLIENT_DIR, 'w'))
