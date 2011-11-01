#!/bin/bash
# Shell : Bash
# Description : Qemu backing images prunning for nova-compute
# Author : razique.mahroua@gmail.com
# Actual version : Version 00

# 		Revision note    
# V00 : Initial version

#  		Notes    	
# This script allows an openstack administrator to purge the compute node for old or unused images.
# Note that when you remove the cached files, the cloud controller needs to send these files to the compute nodes if you run the images the files belong to.
# Thus, instances can require a longer time to run.  
# See : https://answers.launchpad.net/nova/+question/162498
	
# 		Usage
# chmod +x SCR_5008_$version_NUAC-Nova-compute-images-prunning.sh
# ./SCR_5008_$version_NUAC-Nova-compute-images-prunning.sh     

# Binaries
	RM=/bin/rm
	GREP=/bin/grep
	CUT=/usr/bin/cut
	CAT=/bin/cat
	WC=/usr/bin/wc
	LS=/bin/ls
	FIND=/usr/bin/find
	QEMU_IMG=/usr/bin/qemu-img
# Paths
	nova_instances_dir=/var/lib/nova/instances
	nova_instances_base_dir=/var/lib/nova/instances/_base
	tmp_file=/tmp/used_images.tmp

$FIND $nova_instances_dir -name 'disk*' | xargs -n1 $QEMU_IMG info | $GREP backing  > $tmp_file

$LS $nova_instances_base_dir | while read line; do
	file_size="Size : `du -sh $nova_instances_base_dir/$line | cut -f 1 -d "/"`"

	if [ `$GREP  -c "$line" $tmp_file` -ge 1 ]; then
		echo -e "$nova_instances_base_dir/$line is used by a running instance, cannot be removed ! \t $file_size"
	else
		echo -e "$nova_instances_base_dir/$line is not used, the file can safely be removed. \t \t $file_size" 
	fi
done 