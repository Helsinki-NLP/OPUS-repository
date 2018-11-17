
# Using the git backend

Git is used as the default backend for storing data in version-controlled repositories. The structure is as follows:

* each slot is a git repository
* each user branch is a branch in the repository of the slot
* local copies of the user branches of each slot are stored in `$LETSMTDISKROOT/<slot>/<branch>` (which is by default `/var/lib/letsmt/www-data/<slot>/<branch>`)
* the default home dir of the git repositories is `/var/lib/letsmt/www-data/.githome/`


## Setting up remote git servers

Using a remote server for the git repositories requires an established connection to an external git server.

* ssh-keys for data transfer with the git server
* changes to the repository setup



Follow the following steps:


* create a key for connecting with the git server (for example a key called `opus`)
* make the key readable for user `www-data`

```
sudo ssh-keygen -q -t rsa -f /etc/ssh/opusrr -N ""
sudo chown www-data:www-data /etc/ssh/opusrr
sudo chmod 400 /etc/ssh/opusrr
```

* upload the public key (`opusrr.pub`) to the git server
* create a config file for the apache user

```
mkdir -p /var/www/.ssh
echo 'Host *' > /var/www/.ssh/config
echo '  IdentityFile /etc/ssh/opusrr' >> /var/www/.ssh/config
sudo chown -R www-data:www-data /var/www/.ssh
sudo chmod 700 /var/www/.ssh
sudo chmod 400 /var/www/.ssh/config
```

* test the connection (assuming that the server is git@version.helsinki.fi:OPUS)

```
mkdir testslot
chgrp www-data testslot
cd testslot
sudo -u www-data git init
sudo -u www-data git remote add origin git@version.helsinki.fi:OPUS/testslot.git
sudo -u www-data echo test > README
sudo -u www-data git add README
sudo -u www-data git commit -am 'initial commit'
sudo -u www-data git push origin master
```


* install repository software with GIT_REMOTE

```
make GIT_REMOTE='git@github.com:OPUS' install
```
