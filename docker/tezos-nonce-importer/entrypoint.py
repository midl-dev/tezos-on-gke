#!/usr/local/bin/python
import requests
import socket
import time

HOSTNAME = socket.gethostname()
FQDN = socket.getfqdn()

if __name__ == "__main__":
    while True:
        print("Importing nonces")
        other_peer = "-".join(HOSTNAME.split("-")[:-1])
        other_peer_num = ( "0" if HOSTNAME.split("-")[-1] == "1" else "1")
        other_peer += "-" + other_peer_num + "." + ".".join(FQDN.split(".")[1:])
        try:
            nonces = requests.get(f"http://{other_peer}:4247/nonces").json()
        except Exception as e:
            print("could not query other node")
            time.sleep(60)
            continue
        print(nonces)
        time.sleep(60)
