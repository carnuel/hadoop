#!/bin/bash
if [[ $1 == "-bash" || $1 == "-d" ]]; then
        cp /mnt/bootstrap.sh /etc/bootstrap.sh
	chown root:root /etc/bootstrap.sh && chmod 700 /etc/bootstrap.sh

	cp /mnt/copy.sh /etc/copy.sh
	chown root:root /etc/copy.sh && chmod 700 /etc/copy.sh

	/bin/bash /etc/copy.sh
	/bin/bash /etc/bootstrap.sh $1
fi
