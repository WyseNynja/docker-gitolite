#!/bin/sh

# this if will check if the first argument is a flag
# but only works if all arguments require a hyphenated flag
# -v; -SL; -f arg; etc will work, but not arg1 arg2
if [ "${1:0:1}" = '-' ]; then
    set -- /usr/sbin/sshd "$@"
fi

# if command is sshd, set it up correctly
if [ "${1}" = '/usr/sbin/sshd' ] || [ "${1}" = 'sshd' ]; then
  # Setup SSH HostKeys if needed
  # TODO: i think i need to do something more to get rid of dsa here
  for algorithm in rsa ecdsa ed25519
  do
    keyfile=/etc/ssh/keys/ssh_host_${algorithm}_key
    [ -f $keyfile ] || ssh-keygen -q -N '' -f $keyfile -t $algorithm
    grep -q "HostKey $keyfile" /etc/ssh/sshd_config || echo "HostKey $keyfile" >> /etc/ssh/sshd_config
  done
fi

# Fix permissions at every startup
chown -R git:git ~git

# Setup gitolite admin
if [ ! -f ~git/.ssh/authorized_keys ]; then
  if [ -n "$SSH_KEY" ]; then
    [ -n "$SSH_KEY_NAME" ] || SSH_KEY_NAME=admin
    echo "$SSH_KEY" > "/tmp/$SSH_KEY_NAME.pub"
    su - git -c "gitolite setup -pk \"/tmp/$SSH_KEY_NAME.pub\""
    rm "/tmp/$SSH_KEY_NAME.pub"
  else
    echo "You need to specify SSH_KEY on first run to setup gitolite"
    echo "You can also use SSH_KEY_NAME to specify the key name (optional)"
    echo 'Example: docker run -e SSH_KEY="$(cat ~/.ssh/id_rsa.pub)" -e SSH_KEY_NAME="$(whoami)" jgiannuzzi/gitolite'
    exit 1
  fi
# Check setup at every startup
else
  su - git -c "gitolite setup"
fi

if [ "${1}" = '/usr/sbin/sshd' ] || [ "${1}" = 'sshd' ] ; then
  shift
  exec /usr/sbin/sshd -D "$@"
fi

exec "$@"
