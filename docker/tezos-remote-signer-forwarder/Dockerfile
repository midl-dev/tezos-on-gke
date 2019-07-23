FROM alpine:edge

# add openssh and clean
RUN apk add --no-cache openssh shadow

RUN /usr/bin/ssh-keygen -A

RUN adduser --system signer
# * is the hash of the password. Effectively, password login is disabled.
# but I need to do that otherwise sshd says account is locked. see:
#  https://unix.stackexchange.com/a/193131/81131
RUN usermod -p '*' signer

#allow forwarding
RUN sed -ri 's/^.*GatewayPorts.*$/GatewayPorts yes/g' /etc/ssh/sshd_config
RUN sed -ri 's/^.*AllowTcpForwarding.*$/AllowTcpForwarding yes/g' /etc/ssh/sshd_config
RUN sed -ri 's/^.*PasswordAuthentication.*$/PasswordAuthentication no/g' /etc/ssh/sshd_config
RUN printf "AllowUsers signer\n" >> /etc/ssh/sshd_config
RUN cat /etc/ssh/sshd_config

RUN mkdir /home/signer/.ssh && printf "<MY PUBKEY>" > /home/signer/.ssh/authorized_keys && chown -R signer /home/signer

#8433 is remote signer port
#58255 is ssh port
EXPOSE 8433 58255

# -D: do not daemonize
# -e : write logs to standard error
# -p 58255 : port to listen to
CMD ["/usr/sbin/sshd", "-D", "-e", "-p", "58255" ]
