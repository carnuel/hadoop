#!/bin/bash -e
# Turned on -e mode to exit script on errors

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
		false
	fi
}

# Save all args in a array
args=( $@ )
args_len=$(( ${#args[@]} ))
# Variables
mode="" 		# mode
known_hosts=()		# List of all hosts
shell=""		# Shell that should open when container starts

end_script=false
# Iterate through array and set all variables e.g. identify mode (-master or -slave)
for (( i=0; i<$args_len; i++ ))
do
        case ${args[$i]}  in
                "-master")
			if [[ $mode == "-slave" ]]; then
				log 3 "Started bootstrap.sh with arguments -master and -slave. Choose only one."
				end_script=true
			fi
			mode="-master"
                        ;;
		"-slave")
                        if [[ $mode == "-master" ]]; then
                                log 3 "Started bootstrap.sh with arguments -master and -slave. Choose only one."
                                end_script=true
                        fi
                        mode="-slave"
                        ;;
		"-config")
			if [[ $(( ${#known_hosts[@]} )) > 0 ]]; then
				log 3 "Multiple cluster configurations assigned. Please assign only one."
                                end_script=true
			fi
			# Add all following host string to the array, as long as end is not yet reached or no new options has appeared
			while [[ $args_len > $i+1 && ${args[$i+1]} != \-* && $end_script == false ]]; do
				known_hosts[$(( ${#known_hosts[@]} ))]=${args[$i+1]}
				((i++))
			done
			;;
		"-bash")
			if [[ $shell != "" ]]; then
                                log 3 "Multiple starting arguments (-d or -shell). Please assign only one."
                                end_script=true
                        fi
			shell="-bash"
			;;
		"-d")
			if [[ $shell != "" ]]; then
				log 3 "Multiple starting arguments (-d or -shell). Please assign only one."
                                end_script=true
			fi
			shell="-d"
			;;
	esac
done

# End script if the parameter usage is wrong
terminate $end_script

# Check parameters
end_script=false
if [[ $mode == "" ]]; then
	log 3 "No mode chosen (-slave or -master)."
	end_script=true
fi
if [[ $(( ${#known_hosts[@]} )) == 0 ]]; then
	log 3 "No cluster configuration assigned (-config)."
	end_script=true
fi
if [[ $shell == "" ]]; then
        log 3 "No starting argument (-d or -bash). Please assign one."
        end_script=true
fi

# End script if one of the above variables is missing
terminate $end_script

# Variables
master_hostname=""      # Master hostname
master_ip=""            # Master IP
delimiter=";"           # Delimiter to split host string
slaves=()		# Slave host string for /etc/hosts

# Process cluster configuration
for host in "${known_hosts[@]}"
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
                log 3 "Cluster configuration for $host contains too little options (ip;hostname;?type). Remove or extend host options."
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
log 0 "XML templates edited."

# Start ssh
service ssh start
log 0 "SSH started."

# ip of this host
var_ip="$(ifconfig | grep -A 1 'eth0' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)"
# Create the master entry for /etc/hosts
master_entry=$(printf "$master_ip\t$master_hostname")

# Set master mode
if [[ $mode == "-master" ]]; then
	# End script if the master host configuration is not set correctly to this machine.
	if [[ $master_ip != $var_ip ]]; then
		log 3 "Tried to start the master host on the wrong machine. Check the cluster configuration."
		terminate true
	fi
	# Add all slaves to /etc/hosts
	for slave_entry in  "${slaves[@]}"
        do
		if [[ $slave_entry != $master_entry ]]; then
			# Add slave host to /etc/hosts
			echo "${slave_entry}" >> /etc/hosts
			log 0 "$slave_entry added to /etc/hosts."
		fi
        done

	# Formatting namenode, starting namenode and resourcemanager
        $HADOOP_PREFIX/bin/hdfs namenode -format -force
	log 0 "Namenode formatted."
        $HADOOP_PREFIX/sbin/hadoop-daemon.sh start namenode
        log 0 "Namenode started."
        $HADOOP_PREFIX/sbin/yarn-daemon.sh start resourcemanager
	log 0 "Resourcemanager started."
# Set slave mode
elif [[ $mode == "-slave" ]]; then
        # End script if the master host configuration is set wrongly to this machine.
        if [[ $master_ip == $var_ip ]]; then
                log 3 "Tried to start a slave host on the wrong machine. Check the cluster configuration."
                terminate true
        fi
	# Add the master host to /etc/hosts
        echo "${master_entry}" >> /etc/hosts
	log 0 "$master_entry added to /etc/hosts."

	# Starting datanode and nodemanager
	$HADOOP_PREFIX/sbin/hadoop-daemon.sh start datanode
        log 0 "Datanode started."
	$HADOOP_PREFIX/sbin/yarn-daemon.sh start nodemanager
	log 0 "Nodemanager started."
fi

# Run container
log 0 "Running container ..."
if [[ $shell == "-d" ]]; then
	while true; do sleep 1000; done
elif [[ $shell == "-bash" ]]; then
	/bin/bash
fi