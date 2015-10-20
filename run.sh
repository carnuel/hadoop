#!/bin/bash
cp /mnt/bootstrap.sh /etc/bootstrap.sh
chown root:root /etc/bootstrap.sh && chmod 700 /etc/bootstrap.sh

cp /mnt/copy.sh /etc/copy.sh
chown root:root /etc/copy.sh && chmod 700 /etc/copy.sh

/bin/bash /etc/copy.sh
/bin/bash /etc/bootstrap.sh $1
