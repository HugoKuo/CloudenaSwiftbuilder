#!/bin/bash


swift_path=/opt/cloudena/openstack-swift

##These two vars must be set before running functional test##
###     export SWIFT_TEST_CONFIG_FILE=/etc/swift/test.conf
###     export PATH=${PATH}:~/bin

apt-get install -y curl


#Exeute Unit test#
echo 
echo
echo "[Start Unit tests]"
cd $swift_path ; ./.unittests


sleep 2

swift-init main start

#Get an X-Storage-Url and X-Auth-Token
#curl -v -H 'X-Storage-User: test:tester' -H 'X-Storage-Pass: testing' http://127.0.0.1:8082/auth/v1.0

#Check that you can GET account:
#curl -v -H 'X-Auth-Token: <token-from-x-auth-token-above>' <url-from-x-storage-url-above>

#Execute Functional Test
echo
echo
echo "[Start Functional Tests]"
export SWIFT_TEST_CONFIG_FILE=/etc/swift/test.conf
export PATH=${PATH}:/opt/bin
cd $swift_path ; ./.functests
