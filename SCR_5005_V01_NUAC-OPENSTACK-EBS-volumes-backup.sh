#!/bin/bash

# Shell : Bash
# Description : Small nova-volumes backup script
# Author : razique.mahroua@gmail.com
# Actual version : Version 09

# 		Revision note    
# V00 : Initial version
# V01 : The "create_tar" function has been modified, is uses now the second parameter in order to get the volume name
# V02 : In order to speed up the process, md5sum was replaced by sha1sum
# V03 : Add a loop which ckecks that the backup volume is mounted (via sshfs) for every volume, otherwise the backup is aborted 
# V04 : The script uses now "find" instead of the "$dateFileBefore" in order to remove old dumps and old backup. We ensure that if the script fails for whatever reason, old files are removed.
# V05 : Add some extra logging into the create_tar function, so the removed volumes are now emailed ; updated the sections which checks the mount.
# V06 : Fix the SSH connection : log instances list to file ; and added the sourcing of ec2 credentials
# V07 : Add a nice priority on the mysqldump
# V08 : Turn the LVM Snapshots into a function make it easier to enable/ disable the function
#		Add nova-api restart before euca-describe-instances
# V09 : Remove the instances retrieval from the myslq_dump function
#		Renice mysqldump process

# This script is meant to be launched from you cloud-manager server. It connects to all running instances, 
# runs a mysqldump (Debian flavor), mounts the snapshoted LVM volumes and create a TAR on a destination directory. You can disable the mysqldumps if you don't use mysql/ or debian's instances.
# The script can be croned everyday, a rotation makes sure that only a backup per day, for a week exists, while older ones are deleted. When the backup is over, an email is sent to you, with some details.

# A test mode "lvm_test_mode" is available, it allows you to run the whole script for only one LVM volume.
# There is also two interesting settings : "enable_checksum" which allows you to enable or disable a sha1 checksum on the file. Sometimes it could be important to disable it, since the required time for the checksum 
# could ve very long depending on the file size
	
# 		Usage
# chmod +x SCR_5005_$version_NUAC-OPENSTACK-EBS-volumes-backup.sh
# ./SCR_5005_$version_NUAC-OPENSTACK-EBS-volumes-backup.sh           

# Settings
	lvm_test_mode=0
	snapshot_max_size=50
	backups_retention_days=7
	enable_checksum=0
	enable_mysql_dump=1
	enable_lvmsnapshots=1
	enable_mail_notification=1
# Binaries
	MOUNT=/bin/mount
	UMOUNT=/bin/umount
	KPARTX=/sbin/kpartx
	LVREMOVE=/sbin/lvremove
	LVDISPLAY=/sbin/lvdisplay
	LVCREATE=/sbin/lvcreate
	SSH=/usr/bin/ssh
	MYSQLDUMP=/usr/bin/mysqldump
	MKDIR=/bin/mkdir
	RM=/bin/rm
	TAR=/bin/tar
	SHA1SUM=/usr/bin/sha1sum
	GREP=/bin/grep
	AWK=/usr/bin/awk
	HEAD=/usr/bin/head
	CUT=/usr/bin/cut
	WC=/usr/bin/wc
	CAT=/bin/cat
	DU=/usr/bin/du
	DF=/bin/df
	SENDMAIL=/usr/sbin/sendmail
	MOUNT=/bin/mount
	FIND=/usr/bin/find
	TAIL=/usr/bin/tail
	NICE=/usr/bin/nice

#EC2 tools
	EC2_CREDS=/home/adminlocal/.diablo
	EUCA_DESCRIBE=/usr/bin/euca-describe-instances
# Misc
	ssh_params="-o StrictHostKeyChecking=no -T -i /home/adminlocal/creds/nuage.pem"
	ssh_known=/home/adminlocal/.ssh/known_hosts
	ubuntu_ami="ami-00000053"
# Mail
	email_recipient="razique.mahroua@gmail.com"
# MySQL
	mysql_backup_name="mysql-dump"
	mysql_server_dpkg_name="mysql-server"
	mysql_backup_user="mysql_user"
	mysql_backup_pass="mysql_pass"
# Date formats 
	startTime=`date '+%s'`
	dateMail=`date '+%d/%m at %H:%M:%S'`
	dateFile=`date '+%d_%m_%Y'`
	dateFileBefore=`date --date='2 days ago' '+%d_%m_%Y'`
# Paths
	instances_tmp_file=/tmp/instances_list.tmp
	email_tmp_file=/tmp/ebs_backup_status.tmp
	backup_destination=/BACKUPS/EBS-VOL
	check_mount=`echo $backup_destination | $CUT -d "/" -f 2`
	mysql_backup_path=/home/mysql/backup
	mount_point=/mnt
	find_temp_file=/tmp/find_result.tmp
# Messages
	mailnotifications_disabled="The mail notifications are disabled"
	mysqldump_disabled="The mysqldumps are disabled..."
	lvmsnap_disabled="The lv snapshots are disabled..."
	mysql_not_instaled="mysql is not installed, nothing to dump"
	dir_exists="The backup directory exists, nothing to do..."
	old_backups_not_found="Not any old backups to remove..."
	old_backups_found="Removing old backups..."
	mount_ok="The backup volume is mounted. Proceed..."
	mount_ko="The backup volume is not mounted. The backup has been aborted..."

#### ---------------------------------------------- DO NOT EDIT AFTER THAT LINE ----------------------------------------------  #####
# We create the temporary file which will be used for the mail notifications
if [ ! -f $email_tmp_file ]; then
	touch $email_tmp_file
else
	$CAT /dev/null > $email_tmp_file
fi

# We restart nova-api (in order to avoid lazy sessions and instances retrieval fail)
service nova-api restart

# We source the EC2 Credientials and retrieve running instances
. $EC2_CREDS
$EUCA_DESCRIBE | $GREP -v -e "RESERVATION" -e "i-0000009c" > $instances_tmp_file

echo -e "Backup Start Time - $dateMail" >> $email_tmp_file
echo -e "Current retention - $backups_retention_days days \n" >> $email_tmp_file

# 1- Main functions
## Fetch volumes infos
function get_lvs () {
	if [ $lvm_test_mode -eq 0 ]; then
		$LVDISPLAY | $GREP "LV Name" | $AWK '{ print $3 }' 
	else	
		$LVDISPLAY | $GREP "LV Name" | $AWK '{ print $3 }' | $HEAD -1
	fi
}

function get_lvs_name () {
	echo $1 | $CUT -d "/" -f 4
}

function get_lvs_id () {
	echo $1 | $CUT -d "-" -f 3
}

## Mysql dumps
function mysql_backup () {
	while read line; do
		ip_address=`echo $line | cut -f 5 -d " "`
		ami=`echo $line | grep $ubuntu_ami | $WC -l`;
		
		if [ $ami -eq 1 ]; then
   	    	ssh_connect ubuntu
		else
	   	    ssh_connect root
   	    fi
	done < $instances_tmp_file
}

## SSH Connection
function ssh_connect () {
	$CAT /dev/null > $ssh_known 
	$SSH $ssh_params $1@$ip_address <<-EOF
		if [ \`dpkg -l | $GREP $mysql_server_dpkg_name | $WC -l\` -eq 0 ]; then
			echo $mysql_not_instaled;
		else
			# Dump directory creation
			if [ ! -d $mysql_backup_path ]; then
				$MKDIR $mysql_backup_path
			else
				echo $dir_exists;
			fi

			# Dump creation
			$NICE -n 15 $MYSQLDUMP --all-databases -u $mysql_backup_user -p$mysql_backup_pass > $mysql_backup_path/$mysql_backup_name-$dateFile.sql;

			# Old dumps deletion
			$FIND $mysql_backup_path -type f -name "$mysql_backup_name*" -mtime +$backups_retention_days | wc -l > $find_temp_file
			if [ \`cat $find_temp_file\` -ge 1 ]; then
				echo $old_backups_found
				$FIND $mysql_backup_path -type f -name "$mysql_backup_name*" -mtime +$backups_retention_days -exec rm -f {} \;
				rm $find_temp_file
			else
				echo $old_backups_not_found
			fi
		fi
	EOF
}

function time_accounting () {
	timeDiff=$(( $1 - $2 ))
	hours=$(($timeDiff / 3600))
	seconds=$(($timeDiff % 3600))
	minutes=$(($timeDiff / 60))
	seconds=$(($timeDiff % 60))
}

# Snapshot creation
function create_snapshot () {
	$LVCREATE --size $3G --snapshot --name $1-SNAPSHOT $2;
}

# File and applications backups
function create_tar () {
	if [ -d $backup_destination/$2 ]; then
		echo $dir_exists;
	else
		$MKDIR $backup_destination/$2;
	fi
		cd $backup_destination/$2
		$TAR --exclude={"lost+found","mysql/data","mysql/tmp"} -czf $2_$dateFile.tar.gz -C $mount_point . 
		
		if [ $enable_checksum -eq 1 ]; then
			$SHA1SUM $backup_destination/$2/$2_$dateFile.tar.gz > $backup_destination/$2/$2_$dateFile.checksum
		fi
	
	if [ `$FIND $backup_destination -type f -name "$2*" -mtime +$backups_retention_days | wc -l` -ge 1 ]; then
		# Old files deletion
		echo -e "$old_backups_found  : `$FIND $backup_destination -type f -name "$2*" -mtime +$backups_retention_days`" >> $email_tmp_file
		$FIND $backup_destination -type f -name "$2*" -mtime +$backups_retention_days -exec rm -f {} \;
	else 
		echo $old_backups_not_found >> $email_tmp_file
	fi
}

# Iteration through LVM volumes
function lvm_snap() {
	for i in `get_lvs`; do
		startTimeLVM=`date '+%s'`
		
		echo -e "\n ######################### `get_lvs_name $i` #########################"
	
		# We ensure that a backup disk is mounted before proceeding
		if [ `$MOUNT | $GREP "$check_mount" | $WC -l` -eq 1 ]; then
			echo -e $mount_ok >> $email_tmp_file
		else
			echo $mount_ko >> $email_tmp_file
	
		if [ $enable_mail_notification -eq 0 ]; then
			echo $mailnotifications_disabled
		else
			echo -e "---------------------------------------" >> $email_tmp_file
			echo -e "To : $recipient \nSubject : The EBS volumes backup has been aborted the $dateMail ! \n`$CAT $email_tmp_file`" |	 SENDMAIL $email_recipient
			rm $email_tmp_file
		fi
		exit
		fi
	
		echo -e "\n STEP 1 :Snapshot creation"
	 	create_snapshot `get_lvs_name $i` $i $snapshot_max_size 
		
	 	echo -e "\n STEP 2 : Table partition creation"
	 	sleep 1;
	 	$KPARTX -av $i-SNAPSHOT
		
	 	echo -e "\n STEP 3 : Volumes mounting"
	 	sleep 1;
		$MOUNT "/dev/mapper/nova--volumes-volume--`get_lvs_id $i`--SNAPSHOT1" $mount_point
		
		echo -e "\n STEP 4 : Archive creation"
		create_tar $i `get_lvs_name $i`
		
		echo -e "\n STEP 5 : Umount volume"
	 	$UMOUNT $mount_point
		
		echo -e "\n STEP 6 : Table partition remove"
	 	sleep 1;
	 	$KPARTX -d $i-SNAPSHOT
		
		echo -e "\n STEP 7 : Snapshot deletion "
		sleep 1;
	 	$LVREMOVE -f $i-SNAPSHOT
		
		#Time accounting per volume
		time_accounting `date '+%s'` $startTimeLVM
		
		# Mail notification creation
		backup_size=`$DU -h $backup_destination/\`get_lvs_name $i\` | $CUT -f 1`
		echo -e "\t $backup_destination/`get_lvs_name $i` - $hours h $minutes m and $seconds seconds. Size - $backup_size \n" >> 	email_tmp_file	
	done
}

# 1- Databases backup
if [ $enable_mysql_dump -eq 0 ]; then
	echo $mysqldump_disabled >> $email_tmp_file
else
	mysql_backup
fi

# 2- LV backup
if [ $enable_lvmsnapshots -eq 0 ]; then
	echo $lvmsnap_disabled >> $email_tmp_file
else
	lvm_snap
fi

# 3- Mail notification
if [ $enable_mail_notification -eq 0 ]; then
	echo $mailnotifications_disabled
else
	time_accounting `date '+%s'` $startTime
	echo -e "---------------------------------------" >> $email_tmp_file
	echo -e "Total backups size - `$DU -sh $backup_destination | $CUT -f 1` - Used space : `$DF -h $backup_destination | $AWK '{ print $5 }' | $TAIL -n 1`" >> $email_tmp_file
	echo -e "Total execution time - $hours h $minutes m and $seconds seconds" >> $email_tmp_file
	echo -e "To : $recipient \nSubject : The EBS volumes have been backed up in $hours h and $minutes mn the $dateMail \n`$CAT $email_tmp_file`" | $SENDMAIL $email_recipient
fi

# 4- Cleaning
rm $email_tmp_file
rm $instances_tmp_file
