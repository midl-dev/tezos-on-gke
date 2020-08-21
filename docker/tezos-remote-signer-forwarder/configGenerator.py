#!/bin/env python

import json
import os

signer_data = json.loads(os.environ["SIGNER_DATA"])

for node_key, node_val in signer_data["baking_nodes"].items():
    for baker_key, baker_val in node_val.items():
        if "authorized_signers" in baker_val:
            for idx, item in enumerate(baker_val["authorized_signers"]):
                print("%s %s_%s_%s" % (item["ssh_pubkey"], node_key, baker_key, idx), file=open("/home/signer/.ssh/authorized_keys", "a"))

if signer_data["signer_target_host_key"] != "":
    print(signer_data["signer_target_host_key"], file=open("/etc/ssh/ssh_host_rsa_key", "w"))
