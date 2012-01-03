#!/bin/bash

# Shell : Bash
# Description : nova-volume availability check
# Author : razique.mahroua@gmail.com
# Actual version : Version 00

# 		Revision note    
# V00 : Initial version

# This script tries to create a file on a nova-volume disk, and outputs the result to a file. That last can be used by your monitoring system.
	
# 		Usage
# echo -e "# Nova-volume availability check \n" >> /etc/crontab
# echo -e "*/1 * * * * \troot \t /root/SCR_5019_$version_NUAC-OPENSTACK-nova-volume-check.sh" >> /etc/crontab
# chmod +x SCR_5019_$version_NUAC-OPENSTACK-nova-volume-check.sh          

# Binaries
	LOGGER=/usr/bin/logger
	TOUCH=/usr/bin/touch
	MOUNT=/bin/mount
	SENDMAIL=/usr/sbin/sendmail
# Settings
	enable_mail_notification=1
	email_recipient="razique.mahroua@gmail.com"
	mountpoint=/home
	tmp_file=/tmp/mount_status.tmp
	test_file=rw_test.file
	domain="nuage-and-co.net"

# We try to write a file, remove it and retrieve the result
$TOUCH $mountpoint/$test_file > /dev/null 2>&1
RESULT=$?
echo $RESULT > $tmp_file

if [ $RESULT  != "0" ]; then
	$LOGGER "WARNING : Unable to write on the attached volume. Remounting in read-only..."
	# We remount the file in read-only mode
	$MOUNT -o remount,ro $mountpoint

	# We send an email
	if [ $enable_mail_notification -eq 0 ]; then
		$LOGGER "Mail notification are disabled..."
	else
		echo -e "To : $email_recipient \nSubject : WARNING! Unable to write on the EBS volume for `hostname`.$domain" | $SENDMAIL $email_recipient
	fi
else
	rm $mountpoint/$test_file
fi
