#!/bin/bash

###Create Loop devices for storing objects
sudo dd if=/dev/zero of=/srv/swift-disk bs=1024 count=0 seek=1000000
sudo mkfs.xfs -i size=1024 /srv/swift-disk
cat >> /etc/fstab <<EOF
/srv/swift-disk /mnt/sdb1 xfs loop,noatime,nodiratime,nobarrier,logbufs=8 0 0
EOF
sudo mkdir /mnt/sdb1
sudo mount /mnt/sdb1
sudo mkdir /mnt/sdb1/1 /mnt/sdb1/2 /mnt/sdb1/3 /mnt/sdb1/4
for x in {1..4}; do ln -s /mnt/sdb1/$x /srv/$x; done
sudo mkdir -p /srv/1/node/sdb1 /srv/2/node/sdb2 /srv/3/node/sdb3 /srv/4/node/sdb4 /var/run/swift

sleep 2
echo
echo

###SETUP Rsyncd###
echo "[Setting up Rsyncd]"

cat >  /etc/rsyncd.conf <<EOF
uid = root
gid = root
log file = /var/log/rsyncd.log
pid file = /var/run/rsyncd.pid
address = 127.0.0.1

[account36002]
max connections = 25
path = /srv/1/node/
read only = false
lock file = /var/lock/account6012.lock

[account36012]
max connections = 25
path = /srv/2/node/
read only = false
lock file = /var/lock/account6022.lock

[account36022]
max connections = 25
path = /srv/3/node/
read only = false
lock file = /var/lock/account6032.lock

[account36032]
max connections = 25
path = /srv/4/node/
read only = false
lock file = /var/lock/account6042.lock


[container36001]
max connections = 25
path = /srv/1/node/
read only = false
lock file = /var/lock/container6011.lock

[container36011]
max connections = 25
path = /srv/2/node/
read only = false
lock file = /var/lock/container6021.lock

[container36021]
max connections = 25
path = /srv/3/node/
read only = false
lock file = /var/lock/container6031.lock

[container36031]
max connections = 25
path = /srv/4/node/
read only = false
lock file = /var/lock/container6041.lock

[object36000]
max connections = 25
path = /srv/1/node/
read only = false
lock file = /var/lock/object6010.lock

[object36010]
max connections = 25
path = /srv/2/node/
read only = false
lock file = /var/lock/object6020.lock

[object36020]
max connections = 25
path = /srv/3/node/
read only = false
lock file = /var/lock/object6030.lock

[object36030]
max connections = 25
path = /srv/4/node/
read only = false
lock file = /var/lock/object6040.lock


EOF

sed 's/RSYNC_ENABLE=false/RSYNC_ENABLE=true/g' /etc/default/rsync  -i
service rsync restart


sleep 1
echo
echo
###Generate Configuration File##
echo "[Generate Configuration Files]"

mkdir /etc/swift /etc/swift/account-server /etc/swift/container-server /etc/swift/object-server

sleep 1
#Swift.conf#
echo "			|.....Swift.conf"
cat > /etc/swift/swift.conf <<EOF
[swift-hash]
swift_hash_path_suffix = cloudena
EOF

sleep 1
echo "			|"
#proxy-server.conf#
echo "			|.....proxy-server.conf"
cat > /etc/swift/proxy-server.conf << EOF
[DEFAULT]
workers = 1
user = root
bind_port = 8082

[pipeline:main]
pipeline = healthcheck cache tempauth proxy-server

[app:proxy-server]
use = egg:swift#proxy
allow_account_management = true
account_autocreate = true

[filter:tempauth]
use = egg:swift#tempauth
user_admin_admin = admin .admin .reseller_admin
user_test_tester = testing .admin
user_test2_tester2 = testing2 .admin
user_test_tester3 = testing3

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:cache]
use = egg:swift#memcache
EOF


sleep 1
echo "			|"			
#Account Server conf#
echo "			|.....Account Server conf"
for ((i=0;i<4;i=i+1))
do
port=$((36002+i*10))
cat > /etc/swift/account-server/$((i+1)).conf << EOF
[DEFAULT]
devices = /srv/$((i+1))/node
mount_check = false
bind_port = $port
user = root

[pipeline:main]
pipeline = account-server

[app:account-server]
use = egg:swift#account

[account-replicator]
vm_test_mode = yes

[account-auditor]

[account-reaper]

EOF
done	
sleep 1
echo "			|"
#Container Configurations
echo "			|.....Container Server Confs"
for ((i=0;i<4;i=i+1))
do
port=$((36001+i*10))
cat > /etc/swift/container-server/$((i+1)).conf << EOF
[DEFAULT]
devices = /srv/$((i+1))/node
mount_check = false
bind_port = $port
user = root

[pipeline:main]
pipeline = container-server

[app:container-server]
use = egg:swift#container

[container-replicator]
vm_test_mode = yes

[container-updater]

[container-auditor]

[container-sync]
EOF
done

sleep 1
echo "			|"

#Object Configurations
echo "			|.....Object Configurations"
for ((i=0;i<4;i=i+1))
do
port=$((36000+i*10))
cat > /etc/swift/object-server/$((i+1)).conf << EOF
[DEFAULT]
devices = /srv/$((i+1))/node
mount_check = false
bind_port = $port
user = root

[pipeline:main]
pipeline = object-server

[app:object-server]
use = egg:swift#object

[object-replicator]
vm_test_mode = yes

[object-updater]

[object-auditor]

EOF
done
sleep 1
echo
##Setup Test Environment
echo "[Setup Test requires configurations]"
echo "			|.....Export Variables"
echo "					|.....test.conf"
cat > /etc/swift/test.conf <<EOF
[func_test]
# sample config
auth_host = 127.0.0.1
auth_port = 8082
auth_ssl = no
auth_prefix = /auth/

# Primary functional test account (needs admin access to the account)
account = test
username = tester
password = testing

# User on a second account (needs admin access to the account)
account2 = test2
username2 = tester2
password2 = testing2

# User on same account as first, but without admin access
username3 = tester3
password3 = testing3

collate = C
EOF


sleep 2
echo
echo

### Create Rings
echo "[Create Rings for 3 zone 3 replicas]"
swiftp=/usr/local/bin/
cd /etc/swift

rm -f *.builder *.ring.gz backups/*.builder backups/*.ring.gz

${swiftp}/swift-ring-builder object.builder create 18 3 1
${swiftp}/swift-ring-builder object.builder add z1-127.0.0.1:36000/sdb1 1
${swiftp}/swift-ring-builder object.builder add z2-127.0.0.1:36010/sdb2 1
${swiftp}/swift-ring-builder object.builder add z3-127.0.0.1:36020/sdb3 1
${swiftp}/swift-ring-builder object.builder add z4-127.0.0.1:36030/sdb4 1
${swiftp}/swift-ring-builder object.builder rebalance
${swiftp}/swift-ring-builder container.builder create 18 3 1
${swiftp}/swift-ring-builder container.builder add z1-127.0.0.1:36001/sdb1 1
${swiftp}/swift-ring-builder container.builder add z2-127.0.0.1:36011/sdb2 1
${swiftp}/swift-ring-builder container.builder add z3-127.0.0.1:36021/sdb3 1
${swiftp}/swift-ring-builder container.builder add z4-127.0.0.1:36031/sdb4 1
${swiftp}/swift-ring-builder container.builder rebalance
${swiftp}/swift-ring-builder account.builder create 18 3 1
${swiftp}/swift-ring-builder account.builder add z1-127.0.0.1:36002/sdb1 1
${swiftp}/swift-ring-builder account.builder add z2-127.0.0.1:36012/sdb2 1
${swiftp}/swift-ring-builder account.builder add z3-127.0.0.1:36022/sdb3 1
${swiftp}/swift-ring-builder account.builder add z4-127.0.0.1:36032/sdb4 1
${swiftp}/swift-ring-builder account.builder rebalance


