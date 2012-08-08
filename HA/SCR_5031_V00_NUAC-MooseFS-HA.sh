#!/bin/bash
# Shell : Bash
# Description : MooseFS HA Script
# Author : razique.mahroua@gmail.com
# Current version : Version 00

# 		Revision note    
# V00 : Initial version
#
# Binaries
	IP=/bin/ip
	AWK=/usr/bin/awk
	GREP=/bin/grep
	MFSMETALOGGER=/usr/sbin/mfsmetalogger
	MFSMETARESTORE=/usr/sbin/mfsmetarestore
	MFSMASTER=/usr/sbin/mfsmaster
	MFSCGISERV=/usr/sbin/mfscgiserv

# Directories
	mfs_dir="/var/lib/mfs"
	carp_master=172.16.50.11

sleep 2
mkdir -p $mfs_dir/{bak,tmp}

if [[ `$IP addr sh | $GREP "inet $carp_master"` ]]; then
	logger "Saving active files..."
	cp $mfs_dir/changelog.* $mfs_dir/tmp 
	cp $mfs_dir/metadata.* $mfs_dir/tmp

	logger "Restarting the mfsmetalogger service..."
	kill `pidof $MFSMETALOGGER` && $MFSMETALOGGER start

	logger "Running mfsmetarestore..."
	$MFSMETARESTORE -a

	if [[ -f $mfs_dir/metadata.mfs ]]; then
		if [[ -e $mfs_dir/sessions_ml ]]; then
			mv $mfs_dir/sessions_ml.mfs $mfs_dir/sessions.mfs
		fi

		logger "Starting the mfsmaster service..."
		$MFSMASTER start

		logger "Starting the mfscgiserv service..."
		$MFSCGISERV start

		logger "Starting the mfsmetalogger service..."
		if [[ -e $MFSMETALOGGER ]]; then
			$MFSMETALOGGER start
		fi
	fi
else
	logger "Stopping the mfsmaster service..."
	if [[ -n `pidof $MFSMASTER` ]]; then
		kill `pidof $MFSMASTER`
	fi

	logger "Restarting the mfsmetalogger service..."
	if [[ -n `pidof $MFSMETALOGGER` ]]; then
		kill `pidof $MFSMETALOGGER` && $MFSMETALOGGER start
	fi

	logger "Stopping the mfscgiserv service..."
	if [[ `ps aux | $GREP -v grep | $GREP "$MFSCGISERV" | wc -l` -ne "0" ]]; then
		MFSCGISERV_PID=`ps aux | $GREP -v grep | $GREP $MFSCGISERV | $AWK '{print $2}'`
		kill $MFSCGISERV_PID
	fi

	if [[ -f $mfs_dir/metadata.* ]]; then
		mv $mfs_dir/metadata.* $mfs_dir/tmp 
	fi
	if [[ -f $mfs_dir/sessions.* ]]; then
		mv $mfs_dir/sessions.* $mfs_dir/tmp 
	fi
fi

tar -cvf $mfs_dir/bak/metabak.$(date +%s).tgz $mfs_dir/tmp/*