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
	carp_master=172.16.40.45

sleep 2
mkdir -p $mfs_dir/{bak,tmp}

if [[ `$IP addr sh | $GREP "inet $carp_master"` ]]; then
	logger "#1- Saving active files..."
	cp $mfs_dir/changelog.* $mfs_dir/tmp 
	cp $mfs_dir/metadata.* $mfs_dir/tmp

	
	if [[ -z `pidof $MFSMASTER` ]]; then
		logger "#2- Running mfsmetarestore..."
		$MFSMETARESTORE -a
	else
		logger "#2- $MFSMASTER running, skipping mfsmetarestore.."
	fi

	if [[ -f $mfs_dir/metadata.mfs ]]; then
		if [[ -e $mfs_dir/sessions_ml ]]; then
			mv $mfs_dir/sessions_ml.mfs $mfs_dir/sessions.mfs
		fi

		if [[ -z `pidof $MFSMASTER` ]]; then
			logger "#3- Starting the mfsmaster service..."
			$MFSMASTER start
		else
			logger "#3- $MFSMASTER already running, skipping..."
		fi

		if [[ -z `ps aux | $GREP -v grep | $GREP "$MFSCGISERV"` ]]; then
			logger "#4- Starting the mfscgiserv service..."
			$MFSCGISERV start
		else
			logger "#4- $MFSCGISERV already running, skipping..."
		fi

		if [[ -z `pidof $MFSMETALOGGER` ]]; then
			logger "#5- Attempting to launch the mfsmetalogger service..."
			if [[ -e $MFSMETALOGGER ]]; then
				$MFSMETALOGGER start
			fi
		else
			logger "#5- Restart the mfsmetalogger service..."
			$MFSMETALOGGER stop && $MFSMETALOGGER start
		fi
	fi

else
	if [[ -n `pidof $MFSMASTER` ]]; then
		logger "#1- Stopping the mfsmaster service..."
		$MFSMASTER stop
	else
		logger "#1 - $MFSMASTER is not running, skipping..."
	fi

	if [[ -n `pidof $MFSMETALOGGER` ]]; then
		logger "#2- Restarting the mfsmetalogger service..."
		$MFSMETALOGGER stop && $MFSMETALOGGER start
	else
		logger "#2- Starting the mfsmetalogger service..."
		$MFSMETALOGGER start
	fi

	if [[ -n `ps aux | $GREP -v grep | $GREP "$MFSCGISERV"` ]]; then
		logger "#3- Stopping the mfscgiserv service..."
		MFSCGISERV_PID=`ps aux | $GREP -v grep | $GREP $MFSCGISERV | $AWK '{print $3}'`
		kill $MFSCGISERV_PID
	else
		logger "#3- $MFSCGISERV is not running, skipping..."
	fi

	if [[ -f $mfs_dir/metadata.* ]]; then
		mv $mfs_dir/metadata.* $mfs_dir/tmp 
	fi
	if [[ -f $mfs_dir/sessions.* ]]; then
		mv $mfs_dir/sessions.* $mfs_dir/tmp 
	fi
fi

logger "Saving metadatas files..."
tar -cvf $mfs_dir/bak/metabak.$(date +%s).tgz $mfs_dir/tmp/*
