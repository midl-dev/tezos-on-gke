#!/bin/env python

import json
import glob
import os

signer_target_host_key = json.loads(os.environ["SIGNER_TARGET_HOST_KEY"])

# replace all the host keys with the given one
for f in glob.glob("/etc/ssh/ssh_host_*_key*"):
    os.remove(f)
print(signer_target_host_key, file=open("/etc/ssh/ssh_host_ecdsa_key", "w"))
