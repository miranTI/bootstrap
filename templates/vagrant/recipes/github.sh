# trust github fingerprint
# execute as vagrant. Otherwise, known_hosts is created
# at /root/.ssh instead of /home/vagrant/.ssh
sudo -u vagrant ssh -T -oStrictHostKeyChecking=no git@github.com

sudo apt-get install -y git
