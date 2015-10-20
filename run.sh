#!/bin/bash
cp /mnt/*-site.xml.template $HADOOP_PREFIX/etc/hadoop/

cp /mnt/bootstrap.sh /etc/bootstrap.sh
chown root:root /etc/bootstrap.sh
chmod 700 /etc/bootstrap.sh

/bin/bash /etc/bootstrap.sh $1
