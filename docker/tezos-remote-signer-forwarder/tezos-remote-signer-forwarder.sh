#!/bin/sh

python3 configGenerator.py > /home/signer/.ssh/authorized_keys

if [ ! -z $SIGNER_TARGET_HOST_KEY ]; then
    # ssh host key is provided externally
    echo "$SIGNER_TARGET_HOST_KEY" > /etc/ssh/ssh_host_rsa_key
    chmod 440 /etc/ssh/ssh_host_rsa_key
fi

# -D: do not daemonize
# -e : write logs to standard error
# -p 58255 : port to listen to

/usr/sbin/sshd -D -e -p 58255
