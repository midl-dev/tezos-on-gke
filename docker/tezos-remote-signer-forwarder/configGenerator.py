#!/bin/env python

import json
import os

signer_data = json.loads(os.environ["SIGNER_DATA"])

for node_key, node_val in signer_data.items():
    for baker_key, baker_val in node_val.items():
        for idx, item in enumerate(baker_val["authorized_signers"]):
            print("%s %s_%s_%s" % (item["ssh_pubkey"], node_key, baker_key, idx))
