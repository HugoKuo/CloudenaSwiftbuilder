#!/bin/bash

swift-init all stop
sleep 1

rm -r /etc/swift
sleep 1

umount /mnt/sdb1 ; rm -r /mnt/sdb1
rm -r /srv/*

