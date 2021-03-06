#!/bin/sh
# is the number of tezos peer to peer network connections greater than one ?
[ "$(wget -qO - http://127.0.0.1:8732/network/connections | jq '. | length')" -gt 1 ]
