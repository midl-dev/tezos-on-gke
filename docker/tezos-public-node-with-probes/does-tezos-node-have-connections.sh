#!/bin/sh
# is the number of tezos peer to peer network connections greater than one ?
[ "$(wget -qO - http://localhost:8732/network/connections | jq '. | length')" -gt $NUM_CONNECTIONS_IMPLYING_DEAD ]
