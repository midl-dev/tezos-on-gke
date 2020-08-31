#!/bin/sh

# write host and client keys
python3 configGenerator.py
chmod 400 /etc/ssh/ssh_host_ecdsa_key

echo "${SIGNER_PUBKEY} signer" > /home/signer/.ssh/authorized_keys

# -D: do not daemonize
# -e : write logs to standard error
# -p 58255 : port to listen to

/usr/sbin/sshd -D -e -p ${TUNNEL_ENDPOINT_PORT}
