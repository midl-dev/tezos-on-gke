#!/bin/sh

python3 configGenerator.py
chmod 400 /etc/ssh/ssh_host_rsa_key

# -D: do not daemonize
# -e : write logs to standard error
# -p 58255 : port to listen to

/usr/sbin/sshd -D -e -p 58255
