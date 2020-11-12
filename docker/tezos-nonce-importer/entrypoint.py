#!/usr/local/bin/python

# Nonce importer.

# Regularly pings the other node for its nonce file.
# When reomte nodes for the current cycle are found in the other node, but not in the current node, write them to the current node.
import requests
import socket
import time
import json

HOSTNAME = socket.gethostname()
FQDN = socket.getfqdn()

if __name__ == "__main__":
    print("Starting the nonce importer.")
    while True:
        time.sleep(120)
        other_peer = "-".join(HOSTNAME.split("-")[:-1])
        other_peer_num = ( "0" if HOSTNAME.split("-")[-1] == "1" else "1")
        other_peer += "-" + other_peer_num + "." + ".".join(FQDN.split(".")[1:])
        try:
            remote_nonces = requests.get(f"http://{other_peer}:4247/nonces").json()
        except Exception as e:
            print("could not query other node")
            continue

        local_nonces = []
        try:
            with open("/run/tezos/client/nonces", "r") as local_nonces_json:
                local_nonces.extend(json.load(local_nonces_json))
        except Exception as e:
            print("local nonce file not found")

        local_nonce_blocks = [x['block'] for x in local_nonces]

        first_block_in_cycle = int(requests.get("http://localhost:8732/chains/main/blocks/head//helpers/levels_in_current_cycle").json()['first'])

        nonces_to_add = []

        for nonce in remote_nonces:
            if nonce['block'] not in local_nonce_blocks:
                block = requests.get(f"http://localhost:8732/chains/main/blocks/{nonce['block']}").json()
                if int(block['header']['level']) > first_block_in_cycle:
                    print(f"block {nonce['block']} was not found in local nonces")
                    print(f"block {nonce['block']} has height {block['header']['level']}, which is over {first_block_in_cycle}, importing")
                    nonces_to_add.append(nonce)

        if len(nonces_to_add) > 0:
            with open("/run/tezos/client/nonces", "w") as local_nonces_json:
                json.dump(nonces_to_add + local_nonces, local_nonces_json)
