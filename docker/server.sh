[ ! -f /etc/ssh/ssh_host_ecdsa_key ] && ssh-keygen -A

cat /ak/authorized_keys > /home/tun/.ssh/authorized_keys
chown tun:tun /home/tun/.ssh/authorized_keys
chmod 0600 /home/tun/.ssh/authorized_keys
[ ! -d /run/sshd ] && mkdir /run/sshd

exec /usr/sbin/sshd -De -p 22222 -oLogLevel=VERBOSE -oMaxSessions=1000
