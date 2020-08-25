#!/bin/sh

# write host and client keys
python3 configGenerator.py
chmod 400 /etc/ssh/ssh_host_ecdsa_key

# -D: do not daemonize
# -e : write logs to standard error
# -p 58255 : port to listen to

/usr/sbin/sshd -D -e -p 58255
