#!/bin/bash

# Static global variables
CONFIG_FILE="/mnt/cluster.cnf"

# Helper functions
# Check if a given ip is in a valid format
function valid_ip()
{
        # Validate ip pattern
        local ip=$1
	local is_valid='false'
        if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                OIFS=$IFS
                IFS='.'
                ip=($ip)
                IFS=$OIFS
		if [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]; then
			is_valid='true'
		else
			is_valid='false'
		fi
        fi
	echo "$is_valid"
}

# Log messages with different log levels
function log()
{
	local log_args=( $@ )
	local dt=$(date '+%y/%m/%d %H:%M:%S')
	if [[ $(( ${#log_args[@]} )) > 1 ]]; then
		level=$1

		prefix=""
		if [[ $level == 0 ]]; then
			prefix="INFO"
		elif [[ $level == 1 ]]; then
                        prefix="WARN"
		elif [[ $level == 2 ]]; then
                        prefix="ERROR"
		elif [[ $level == 3 ]]; then
                        prefix="FATAL"
		fi

		echo "$dt $prefix $2"
	fi
}

# Ending the script
function terminate()
{
	if [[ $1 == true ]]; then
        	log 0 "Ending script."
		exit 0
	fi
}

end_script=false
# Check if cluster.cnf exists
if [ ! -f $CONFIG_FILE ]; then
	log 3 "No cluster configuration found at /mnt/cluster.cnf."
	end_script=true
fi
if [[ $1 != "-bash" && $1 != "-d" ]]; then
	log 3 "Not started with -bash or -d."
	end_script=true
fi
terminate $end_script
# Variables
master_hostname=""      # Master hostname
master_ip=""            # Master IP
delimiter=";"           # Delimiter to split host string
slaves=()		# Slave host string for /etc/hosts

# Process cluster configuration
for host in $(cat $CONFIG_FILE)
do
        # e.g. 136.199.51.110;ssds110.dbnet.syssoft.uni-trier.de;master
        # Host options
        host_ip=""
        host_name=""
        host_type=""

	# Split the host string
        IFS=$delimiter read -ra host_split <<< "$host"
	host_split_len=$(( ${#host_split[@]} ))

	end_script=false
	# Set host options
	if [[ $host_split_len == 0 ]]; then
		# Empty line in cluster configuration
		continue
	elif [[ $host_split_len > 1 ]]; then
        	host_ip=${host_split[0]}
        	host_name=${host_split[1]}
		if [[ $host_split_len > 2 ]]; then
			host_type=${host_split[2]}
		fi
	else
                log 3 "Cluster configuration for $host contains too little options (ip;hostname;?type). Remove or extend the host options."
                end_script=true
	fi

	# Check host options
        if [[ $(valid_ip $host_ip) == false ]]; then
		log 3 "$host is no valid ip. Check cluster configuration."
		end_script=true
        fi
        if [[ $host_ip == "" ]]; then
		log 3 "No hostname for host $host."
		end_script=true
        fi

	# In case of type master set the master ip and hostname.
	if [[ $host_type == "master" ]]; then
		if [[ $master_ip == "" && $master_hostname == "" ]]; then
			master_ip=$host_ip
			master_hostname=$host_name
		else
			log 3 "Multiple master hosts assigned. Check cluster configuration."
			end_script=true
		fi
	# In other cases add a new slave to the array
	else
		slaves[$(( ${#slaves[@]} ))]=$(printf "$host_ip\t$host_name")
	fi
	# End script when ip or hostname is missing or invalid or when there are multiple master hosts chosen.
        terminate $end_script
done

end_script=false
# Check master options
if [[ $master_ip == "" ]]; then
	log 3 "No master ip assigend."
	end_script=true
fi
if [[ $master_hostname == "" ]]; then
        log 3 "No master hostname assigned."
        end_script=true
fi
if [[ $(( ${#slaves[@]} )) == 0 ]]; then
	log 3 "No slaves assigned."
	end_script=true
fi
# End script if no master or slaves are given
terminate $end_script

# Edit xml.templates
sed s/HOSTNAME/$master_ip/ $HADOOP_PREFIX/etc/hadoop/core-site.xml.template > $HADOOP_PREFIX/etc/hadoop/core-site.xml
sed s/HOSTNAME/$master_hostname/ $HADOOP_PREFIX/etc/hadoop/yarn-site.xml.template > $HADOOP_PREFIX/etc/hadoop/yarn-site.xml
sed s/HOSTNAME/$master_hostname/ $HADOOP_PREFIX/etc/hadoop/mapred-site.xml.template > $HADOOP_PREFIX/etc/hadoop/mapred-site.xml

log 0 "XML templates edited."

# Start ssh
service ssh start
log 0 "SSH started."

# ip of this host
var_ip="$(ifconfig | grep -A 1 'eth0' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)"

# Start editing /etc/hosts in a temporary file
# Add second localhost hostname
# Remove 127.0.1.1
sed -e "s/127.0.1.1/$var_ip/" -e '/127.0.0.1/c 127.0.0.1\tlocalhost\tlocalhost' /etc/hosts > /tmp/hosts
log 0 "Changed 127.0.1.1 to $var_ip."

# Set master mode
if [[ $var_ip == $master_ip ]]; then
	# Add all slaves to /etc/hosts
	for slave_entry in  "${slaves[@]}"
        do
		# Add slave host to /etc/hosts
		echo "${slave_entry}" >> /tmp/hosts
		log 0 "$slave_entry added to /tmp/hosts."
        done

	# Replace the original /etc/hosts
        cp /tmp/hosts /etc/hosts
	rm /tmp/hosts
	log 0 "Replaced /etc/hosts."

	# Formatting namenode, starting namenode and resourcemanager
        $HADOOP_PREFIX/bin/hdfs namenode -format -force
	log 0 "Namenode formatted."
        $HADOOP_PREFIX/sbin/hadoop-daemon.sh start namenode
        log 0 "Namenode started."
        $HADOOP_PREFIX/sbin/yarn-daemon.sh start resourcemanager
	log 0 "Resourcemanager started."
# Set slave mode
else
	# Create the master entry for /etc/hosts
	master_entry=$(printf "$master_ip\t$master_hostname")

	# Add the master host to /etc/hosts
        echo "${master_entry}" >> /tmp/hosts
	log 0 "$master_entry added to /tmp/hosts."

	# Replace the original /etc/hosts
        cp /tmp/hosts /etc/hosts
        rm /tmp/hosts
	log 0 "Replaced /etc/hosts."

	# Starting datanode and nodemanager
	$HADOOP_PREFIX/sbin/hadoop-daemon.sh start datanode
        log 0 "Datanode started."
	$HADOOP_PREFIX/sbin/yarn-daemon.sh start nodemanager
	log 0 "Nodemanager started."
fi

# Run container
log 0 "Running container ..."
if [[ $1 == "-d" ]]; then
	while true; do sleep 1000; done
elif [[ $1 == "-bash" ]]; then
	/bin/bash
fi
