#!/bin/bash

# Shell : Bash
# Description : Small nova-controllerbackup script
# Author : razique.mahroua@gmail.com
# Actual version : Version 00

# 		Revision note    
# V00 : Initial version
# V01 : Added a function which checks the destination volume exists
#		Better formatting the mail report
#		Rework on the function executions order

#  		Notes    	
# This script is meant to be launched from you cloud-manager server. It allows you to indicate some folders on your server to backup.
# The script tar these files and send them to a backup director (in my case a NFS export). The script is meant to be run everyday (via a cron entry for instance).
# Through the "backups_retention_days" variable, you can control for how many days the backups are kept. 
# The script also make a dump of all the databases (in my case nova + glance ) and apply the same policy for naming and rotating the dumps.
	
# 		Usage
# chmod +x SCR_5009_$version_NUAC-OPENSTACK-Cloud-controller-backup.sh
# ./SCR_5009_$version_NUAC-OPENSTACK-Cloud-controller-backup.sh           

# Settings
	backups_retention_days=7
	enable_checksum=1
	enable_mysql_dump=1
	enable_mail_notification=1
	node_name="NOVA-CC1"
# Binaries
	MOUNT=/bin/mount
	MYSQLDUMP=/usr/bin/mysqldump
	MKDIR=/bin/mkdir
	RM=/bin/rm
	TAR=/bin/tar
	SHA1SUM=/usr/bin/sha1sum
	GREP=/bin/grep
	HEAD=/usr/bin/head
	CUT=/usr/bin/cut
	AWK=/usr/bin/awk
	WC=/usr/bin/wc
	CAT=/bin/cat
	DU=/usr/bin/du
	DF=/bin/df
	SENDMAIL=/usr/sbin/sendmail
	FIND=/usr/bin/find
	TAIL=/usr/bin/tail
# Mail
	email_recipient="razique.mahroua@gmail.com"
# MySQL
	mysql_backup_name="mysql-dump"
	mysql_server_dpkg_name="mysql-server"
	mysql_backup_user="root"
	mysql_backup_pass="root_pass"
# Date formats 
	startTime=`date '+%s'`
	dateMail=`date '+%d/%m at %H:%M:%S'`
	dateFile=`date '+%d_%m_%Y'`
# Paths
	email_tmp_file=/root/backup_status.tmp
	backup_destination=/BACKUPS/EBS-VOL
	check_mount=`echo $backup_destination | $CUT -d "/" -f 2`
	find_temp_file=/tmp/find_result.tmp
# Messages
	mailnotifications_disabled="The mail notifications are disabled"
	mysqldump_disabled="The mysqldumps are disabled"
	dir_exists="The backup directory exists, nothing to do..."
	old_backups_not_found="Not any old backups to remove..."
	old_backups_found="Removing old backups..."
	mount_ok="The backup volume is mounted. Proceed..."
	mount_ko="The backup volume is not mounted. The backup has been aborted..."

# Directories to backup
paths=(
	"/root/creds"
	"/home/adminlocal"
	"/etc/nova"
	"/var/lib/nova"
)

#### ---------------------------------------------- DO NOT EDIT AFTER THAT LINE ----------------------------------------------  #####
# We create the temporary file which will be used for the mail notifications
if [ ! -f $email_tmp_file ]; then
	touch $email_tmp_file
else
	$CAT /dev/null > $email_tmp_file
fi

echo -e "Backup Start Time - $dateMail" >> $email_tmp_file
echo -e "Current retention - $backups_retention_days days \n" >> $email_tmp_file

# Time accounting
function time_accounting () {
	timeDiff=$(( $1 - $2 ))
	hours=$(($timeDiff / 3600))
	seconds=$(($timeDiff % 3600))
	minutes=$(($timeDiff / 60))
	seconds=$(($timeDiff % 60))
}

# This function is used in order to make sure the destination is mounted
function check_mount () {
	if [ `$MOUNT | $GREP "$check_mount" | $WC -l` -eq 1 ]; then
		mount_result=1
	else
		mount_result=0
	fi
}

## Mysql dumps
function mysql_backup () {
	if [ -d $backup_destination/$node_name/$mysql_backup_name ]; then
		echo $dir_exists 
	else
		$MKDIR -p $backup_destination/$node_name/$mysql_backup_name
	fi
	
	$MYSQLDUMP --all-databases -u $mysql_backup_user -p$mysql_backup_pass > $backup_destination/$node_name/$mysql_backup_name/$mysql_backup_name-$dateFile.sql;

	# We remove the old dumps
	$FIND $backup_destination/$node_name -type f -name "$mysql_backup_name*" -mtime +$backups_retention_days | wc -l > $find_temp_file
	if [ `cat $find_temp_file` -ge 1 ]; then
		echo -e "$old_backups_found  : `$FIND $backup_destination/$node_name -type f -name "$mysql_backup_name*" -mtime +$backups_retention_days`" >> $email_tmp_file
		$FIND $backup_destination/$node_name -type f -name "$mysql_backup_name*" -mtime +$backups_retention_days -exec rm -f {} \;
		rm $find_temp_file
	else
		echo "$old_backups_not_found" >> $email_tmp_file
		echo "$backup_destination/$node_name/$mysql_backup_name/" >> $email_tmp_file
	fi
}

## We iterate through the paths defined into the array in order to create an archive for every directory.
function create_tar () {

	if [ -d $backup_destination/$node_name ]; then
		echo "$node_name -$dir_exists"
	else
		$MKDIR -p $backup_destination/$node_name;
	fi

	cd $backup_destination/$node_name
	for i in ${paths[*]}; do
		
		startTimeTAR=`date '+%s'`
		filename=`echo $i | sed "s/\//_/g"`
		echo -e "\n------------------ $i --------------------" >> $email_tmp_file
		if [ -d $filename ]; then
			echo $dir_exists && cd $filename
		else
			$MKDIR -p $filename && cd $filename
		fi
		
		$TAR -czf $filename-$dateFile.tar.gz -C $i .
		
		if [ $enable_checksum -eq 1 ]; then
			$SHA1SUM $backup_destination/$node_name/$filename/$filename-$dateFile.tar.gz > $backup_destination/$node_name/$filename/$filename-$dateFile.checksum
		fi
		
		if [ `$FIND $backup_destination/$node_name -type f -name "$filename*" -mtime +$backups_retention_days | wc -l` -ge 1 ]; then
			# Old files deletion
			echo -e "$old_backups_found  : `$FIND $backup_destination/$node_name -type f -name "$filename*" -mtime +$backups_retention_days`" >> $email_tmp_file
			$FIND $backup_destination/$node_name -type f -name "$filename*" -mtime +$backups_retention_days -exec rm -f {} \;
		else 
			echo "$old_backups_not_found" >> $email_tmp_file

		fi

		# Spent time calculation
		time_accounting `date '+%s'` $startTimeTAR
		backup_size=`$DU -h $backup_destination/$node_name/$filename/$filename-$dateFile.tar.gz | $CUT -f 1`
		echo -e "$backup_destination/$node_name/$filename/$filename-$dateFile.tar.gz - $hours h $minutes m and $seconds seconds. Size - $backup_size" >> $email_tmp_file
	done
}

# 1- Database backup and archive creation
check_mount

if [ $mount_result -eq 1 ]; then
	echo -e "\t $mount_ok" >> $email_tmp_file
	echo -e "###########################################" >> $email_tmp_file
	create_tar
	echo -e "---------------------------------------\n" >> $email_tmp_file

	if [ $enable_mysql_dump -eq 0 ]; then
		echo $mysqldump_disabled >> $email_tmp_file
	else
		mysql_backup
	fi
else
	echo -e "\t $mount_ko" >> $email_tmp_file
	echo -e "###########################################" >> $email_tmp_file

	if [ $enable_mail_notification -eq 0 ]; then
		echo $mailnotifications_disabled
	else
		echo -e "---------------------------------------" >> $email_tmp_file
		echo -e "To : $recipient \nSubject : The $node_name backup has been aborted the $dateMail ! \n`$CAT $email_tmp_file`" | $SENDMAIL $email_recipient
		rm $email_tmp_file
	fi
	exit
fi

# 2- Mail notification
if [ $enable_mail_notification -eq 0 ]; then
	echo $mailnotifications_disabled
else
	time_accounting `date '+%s'` $startTime
	echo -e "---------------------------------------" >> $email_tmp_file
	echo -e "Total backups size - `$DU -sh $backup_destination/$node_name | $CUT -f 1` - Used space on disk : `$DF -h $backup_destination/$node_name | $AWK '{ print $4 }' | $TAIL -n 1`" >> $email_tmp_file
	echo -e "Total execution time - $hours h $minutes m and $seconds seconds" >> $email_tmp_file
	echo -e "To : $recipient \nSubject : The $node_name files have been backed up in $hours h and $minutes mn the $dateMail \n`$CAT $email_tmp_file`" | $SENDMAIL $email_recipient
fi

rm $email_tmp_file

