#!/bin/bash

# Shell : Bash
# Description : ssh' permanent tunnel
# Author : razique.mahroua@gmail.com
# Actual version : Version 00

# 		Revision note    
# V00 : Initial version

# The script creates a permanent SSH tunnel to a remote server using an intermediary one. So the public key of the user which runs the script (basically root) 
# needs to send it's public key on both servers.
# This script needs to be croned in order to run every minute, e.g : 
#	SHELL=/bin/sh
#	PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

	# m h dom mon dow user	command
#	 01 * * * *	root    /path/SCR_5010_
	
# 		Usage
# chmod +x SCR_5010_$version_NUAC-ssh-permanent-tunnel.sh
# ./SCR_5010_$version_NUAC-ssh-permanent-tunnel.sh    

# Variables
	currentdate="$(date +%d-%m-%Y:%H:%M:%S)"
	monitor_process=autossh
	recipient="razique.mahroua@gmail.com"

# Binaries
	GREP=/bin/grep
	PS=/bin/ps
	LOGGER=/usr/bin/logger
	SENDMAIL=/usr/sbin/sendmail
	AUTOSSH=/usr/bin/autossh
	SSH=/usr/bin/ssh
	WC=/usr/bin/wc

# Settings
	main_server_user="root"
	main_server_port=22
	main_server_pub_ip="XXX.XXX.XXX.XXX"
   	main_server_priv_ip="YYY.YYY.YYY.YYY"
   	local_port=1500
	remote_port=2500
	enable_notification=1

#### ---------------------------------------------- DO NOT EDIT AFTER THAT LINE ----------------------------------------------  #####

# The function launches the tunnel
function launch_tunnel (){
	$SSH -N -f -T $main_server_user@$main_server_pub_ip -p $main_server_port -L:$local_port:$main_server_priv_ip:$remote_port
}

# The function send to the syslog somes messages
function logging (){
	$LOGGER "The tunnel is down running at $currentdate"
	$LOGGER "Starting the tunnel..."
}

check_process=`$PS ax | $GREP -v grep | $GREP $main_server_pub_ip | $WC -l`

if [ $check_process -eq 1 ]; then
	$LOGGER "The tunnel is running at $currentdate"
else
	if [ $enable_notification -eq 0 ]; then
		$LOGGER "Mail notifications disabled"
		logging
	else	
		echo -e "To : $recipient \nSubject : The SSH tunnel is down on `hostname`" | $SENDMAIL -F root@`hostname` $recipient
		logging
	fi
	launch_tunnel
fi