#!/bin/bash

# Shell : Bash
# Description : Instances Swap provisionning script
# Author : razique.mahroua@gmail.com
# Actual version : Version 01

# 		Revision note    
# V00 : Initial version
# V01 :	Add a condition which checks the total amount of memory and set the size accordingly
#		Add a function which unmounts the swap

# This script creates a swapfile and enable it based on the instance's RAM. 
# Because instance's flavor can be updated, the script should be run from /etc/rc.local
	
# 		Usage
# chmod +x SCR_5016_$version_NUAC-OPENSTACK-Swap-provisionning.sh
# ./SCR_5016_$version_NUAC-OPENSTACK-Swap-provisionning.sh           

# Binaries
	AWK=/usr/bin/awk
	LOGGER=/usr/bin/logger
	DD=/bin/dd
	MKSWAP=/sbin/mkswap
	SWAPON=/sbin/swapon
	SWAPOFF=/sbin/swapoff
# Settings
	SWAP_FILE=/swapfile

# We retrieve the memory the server has
TOTAL_MEMORY=`$AWK '/MemTotal/ {printf( "%.0f\n", $2/1024 )}' /proc/meminfo`

# We calculate the swap size based on the available memory
if [ $TOTAL_MEMORY -gt 512 ]; then 
	SWAP_SIZE=`echo $(($TOTAL_MEMORY/2+2))`
else
	SWAP_SIZE=`echo $(($TOTAL_MEMORY*2+2))`
fi

# We setup a threshold
if [ $SWAP_SIZE -gt 1024 ]; then
	SWAP_SIZE=1024
fi

function create_swapfile() {
	$DD if=/dev/zero of=$SWAP_FILE bs=1M count=$SWAP_SIZE
	$MKSWAP $SWAP_FILE
}

function unmount_swap() {
	$SWAPOFF $SWAP_FILE > /dev/null 2>&1
}

# If the file already exists, we don't bother to create another one
if [ -f $SWAP_FILE ]; then
	# We make sure the file is not busy first
	$LOGGER "Unmounting swap file..."
	unmount_swap
	OUTPUT=$?

	if [ $OUTPUT -eq 0 ]; then
		$LOGGER "Swapfile not mounted, nothing to do..."

	else
		$LOGGER "Unmounting swap file..."
		unmount_swap
	fi

	ORIGINAL_FILE=`du -ac $SWAP_FILE | tail -1 | cut -f 1`
	SWAP_FILE_MB=$((SWAP_SIZE*1024))
	if [ $ORIGINAL_FILE -gt $SWAP_FILE_MB ]; then
		$LOGGER "Swapfile already exists, nothing to create..."
	else
		create_swapfile
	fi
else
	create_swapfile
fi

# We enable the file
$SWAPON $SWAP_FILE 
