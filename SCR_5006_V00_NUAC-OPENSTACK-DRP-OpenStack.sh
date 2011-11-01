#!/bin/bash

# Shell : Bash
# Description : Small Openstack DRP script 
# Author : razique.mahroua@gmail.com
# Actual version : Version 00

# 		Revision note    
# V00 : Initial version
  
#  		Notes    	
# This script is used for an Openstack Disaster Recovery Process. The script will be used every time there is a connection loose between the cloud controller and the compute-node.
# The script has been designed in a way, it uses nova-volumes. Here are the steps the script does :
#
# 	1- An array is created for instances and their attached volumes
# 	2- The MySQL database is updated
#	3- Using euca2ools, all the instances are restarted
#	4- The volume attachement is made
#	5- Then an SSH connection is performed into every instance using nova credentials
#
#
#	A test mode is providen, it allows you to speicify an instance id, and only that instance will go through the DRP script. Others instances won't be impacted.
#	In order to use it, be sure to manually close the iscsi session from the nova-compute.
	
# 		Usage
# chmod +x SCR_5005_$version_NUAC-DRP-OpenStack.sh
# ./SCR_5005_$version_NUAC-DRP-OpenStack.sh                     

# Binaries
	SSH=/usr/bin/ssh
	MYSQL=/usr/bin/mysql
	GREP=/bin/grep
	AWK=/usr/bin/awk
	HEAD=/usr/bin/head
	CUT=/usr/bin/cut
	WC=/usr/bin/wc
	CAT=/bin/cat
	SED=/bin/sed
# Misc
	# The test moade allows the whole process to run to a test instance only. The instance id has to be set into the "instance_test_id" variable. It supposes that you have created a dummy instances and attached an EBS volume to it.
	test_mode=1
	instance_test_id="i-000000a8"
		
	ssh_params="-o StrictHostKeyChecking=no -T -i /root/creds/nuage.pem"
	ssh_known="/root/.ssh/known_hosts"
	ubuntu_ami="ami-0000000b"
	volumes_tmp_file=/home/adminlocal/vol_instances.tmp
	validation="no"
# MySQL
	mysql_user="root"
	mysql_pass="root_pass"

#### ---------------------------------------------- DO NOT EDIT AFTER THAT LINE ----------------------------------------------  #####

function create_vol_instance_assoc () {
	# We first create a temp file which associates each instance to it's volume	
	$CAT /dev/null > vol_instances.tmp
	get_instances=`euca-describe-volumes | $AWK '{print $2,"\t",$8,"\t,"$9}' | $GREP -v "None" | $SED "s/\,//g; s/)//g; s/\[.*\]//g; s/\\\\\//g"`
	
	if [ $test_mode -eq 1 ]; then
		 echo "$get_instances" | $GREP $instance_test_id > $volumes_tmp_file
	else
    	 echo "$get_instances" > $volumes_tmp_file
	fi
}

function update_database (){
	# We reset the database so the volumes are reset to an available state
	if [ $test_mode -eq 1 ]; then
		$MYSQL -u$mysql_user -p$mysql_pass <<-EOF
			use nova;
			UPDATE volumes JOIN instances AS i ON volumes.instance_id = i.id SET mountpoint="NULL" WHERE i.hostname = "$instance_test_id";
			UPDATE volumes JOIN instances AS i ON volumes.instance_id = i.id SET status="available" WHERE i.hostname = "$instance_test_id" AND volumes.status <> "error_deleting";
			UPDATE volumes JOIN instances AS i ON volumes.instance_id = i.id SET attach_status="detached" WHERE i.hostname = "$instance_test_id";
			UPDATE volumes JOIN instances AS i ON volumes.instance_id = i.id SET instance_id=0 WHERE i.hostname = "$instance_test_id";
		EOF
	else
		$MYSQL -u$mysql_user -p$mysql_pass <<-EOF
			use nova;
			update volumes set mountpoint=NULL;
			update volumes set status="available" where status <> "error_deleting";
			update volumes set attach_status="detached";
			update volumes set instance_id=0;	
		EOF
	fi	
}

function euca_reboot_instances () {
	# We go from a "shutown" to a "running" stage
	reboot_instances=`euca-describe-instances | $GREP -v "RESERVATION" `
	if [ $test_mode -eq 1 ]; then	
		echo "$reboot_instances" | $GREP $instance_test_id | while read line; do
			instance=`echo $line | cut -f 2 -d " "`
			echo "REBOOTING INSTANCE - $instance"
			euca-reboot-instances $instance
			sleep 2
		done 
	else
		echo "$reboot_instances" | while read line; do
			instance=`echo $line | cut -f 2 -d " "`
			echo "REBOOTING INSTANCE - $instance"
			euca-reboot-instances $instance
			sleep 2
		done
	fi	
}

function attach_volume (){
	# For every instance, we restore it's volume
	while read line; do
		volume=`echo $line | $CUT -f 1 -d " "`
		instance=`echo $line | $CUT -f 2 -d " "`
		mount_point=`echo $line | $CUT -f 3 -d " "`
		echo "ATTACHING VOLUME FOR INSTANCE - $instance"
		euca-attach-volume -i $instance -d $mount_point $volume
		sleep 2
	done < $volumes_tmp_file
}

function restart_instances (){
	# We SSH to the instances in order to restart them
	restart_instances=`euca-describe-instances | $GREP -v -e "RESERVATION" -e "i-0000009c"`
	
	if [ $test_mode  -eq 1 ]; then
		echo "$restart_instances" | grep $instance_test_id | while read line; do
			ip_address=`echo $line | cut -f 5 -d " "`
			echo "RESTARTING INSTANCE - $ip_address"
			ami=`echo $line | grep $ubuntu_ami | $WC -l`;
				if [ $ami -eq 1 ]; then
					go_sudo="yes"
   	   				ssh_connect ubuntu
				else
					go_sudo="no"
	   	    		ssh_connect root
   	    		fi	
			done	
	else
		echo -e "$restart_instances" | while read line; do
		ip_address=`echo $line | cut -f 5 -d " "`
		echo "RESTARTING INSTANCE - $ip_address"
		ami=`echo $line | grep $ubuntu_ami | $WC -l`;	
			if [ $ami -eq 1 ]; then
				go_sudo="yes"
   	    		ssh_connect ubuntu
			else
				go_sudo="no"
	   	    	ssh_connect root
   	    	fi	
		done
	fi
}

function ssh_connect () {
	$CAT /dev/null > $ssh_known 
	$SSH $ssh_params $1@$ip_address <<-EOF
	echo "The server will reboot now...";
		if [ $go_sudo == "yes" ]; then
			sudo shutdown -r now	
		else
			shutdown -r now
		fi
	EOF
}

echo -e "WARNING : YOU ARE ABOUT TO RESTART ALL RUNNING INSTANCES AND REAFFECT VOLUMES. IS IT REALLY WHAT YOU WANT? [YES/NO]: "
read validation
shopt -s nocasematch
	if [ $validation ==  "no" ]; then
		echo "EXITTING..."
		exit
	elif [ $validation ==  "yes" ]; then
		if [ $test_mode  -eq 1 ]; then
			echo "## ENTERING TEST MODE USING $instance_test_id ##"
		fi
		
		echo -e "\n STEP 1 : File populating"
			create_vol_instance_assoc
		
		echo -e "\n STEP 2 : Database update"
			update_database
		
		echo -e "\n STEP 3 : Instances restart"
			euca_reboot_instances
		
		echo -e "\n STEP 4 : Volumes attachment"
			attach_volume
		
		echo -e "\n STEP 5 : Server restart"
			sleep 15
			restart_instances
		
		rm $volumes_tmp_file
	else
		echo -e "Please answer by typing yes or no"
		echo -e "EXITTING..."
		exit
	fi
shopt -u nocasematch
