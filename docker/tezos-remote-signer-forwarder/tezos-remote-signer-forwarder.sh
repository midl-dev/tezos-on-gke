#!/bin/sh
echo "$AUTHORIZED_SIGNER_KEY_A" >> /home/signer/.ssh/authorized_keys
echo "$AUTHORIZED_SIGNER_KEY_B" >> /home/signer/.ssh/authorized_keys

# -D: do not daemonize
# -e : write logs to standard error
# -p 58255 : port to listen to

/usr/sbin/sshd -D -e -p 58255
