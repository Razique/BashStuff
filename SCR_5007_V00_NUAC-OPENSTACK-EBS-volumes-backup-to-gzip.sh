#!/bin/bash

# Shell : Bash
# Description :Small logical volume to gzip backup script
# Author : razique.mahroua@gmail.com
# Actual version : Version 00

# 		Revision note    
# V00 : Initial version
  
#  		Notes    	
# This script is meant to be launched from you cloud-manager server. It creates a snapshot of every LVM volumes, gzip it, and sent it to a directory.
# The difference between the SCR_5004_$version_NUAC-Sauvegarde-Volumes-EBS.sh script is that the logical volume is backuep to a .img.gz file. It is meant to be used in order to have 
# images backup that could be easily reinjected into another logical volume

# You can specify how many backups you want to keep per file by changing the $dateFileBefore variable. By default, the script, if run every day, keeps 7 (seven) backups.

# A test mode "lvm_limit_one" is available, it allows you to run the whole script for only one LVM volume.
	
# 		Usage
# chmod +x SCR_5007_$version_NUAC-Sauvegarde-Volumes-EBS-vers-gzip.sh

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
	MD5SUM=/usr/bin/md5sum
	GREP=/bin/grep
	AWK=/usr/bin/awk
	HEAD=/usr/bin/head
	CUT=/usr/bin/cut
	WC=/usr/bin/wc
	CAT=/bin/cat
	DU=/usr/bin/du
	DD=/bin/dd
	GZIP=/bin/gzip
	SENDMAIL=/usr/sbin/sendmail
# Misc
	lvm_limit_one=1
	snapshot_max_size=50
	block_size=16M
# Mail
	enable_mail_notification=1
	email_recipient="razique.mahroua@gmail.com"
# Date formats 
	startTime=`date '+%s'`
	dateMail=`date '+%d/%m at %H:%M:%S'`
	dateFile=`date '+%d_%m_%Y'`
	dateFileBefore=`date --date='1 week ago' '+%d_%m_%Y'`
# Paths
	email_tmp_file=/root/ebs_backup_status.tmp
	backup_destination=/var/lib/glance/images/BACKUP/GZIP-EBS-VOL
# Messages
	mailnotifications_disabled="The mail notifications are disabled"
	dir_exists="The directory already exists"
	nothing="Nothing to remove"

#### ---------------------------------------------- DO NOT EDIT AFTER THAT LINE ----------------------------------------------  #####
if [ ! -f $email_tmp_file ]; then
	touch $email_tmp_file
else
	$CAT /dev/null > $email_tmp_file
fi
echo -e "Backup Start Time - $dateMail" >> $email_tmp_file

# 1- Main functions

## Fetch volumes infos
function get_lvs () {
	if [ $lvm_limit_one -eq 0 ]; then
		$LVDISPLAY | $GREP "LV Name" | $AWK '{ print $3 }' 
	else	
		$LVDISPLAY | $GREP "LV Name" | $AWK '{ print $3 }' | $HEAD -1
	fi
}

function get_lvs_name () {
	echo $1 | $CUT -d "/" -f 4
}

function time_accounting () {
	timeDiff=$(( $1 - $2 ))
	hours=$(($timeDiff / 3600))
	seconds=$(($timeDiff % 3600))
	minutes=$(($timeDiff / 60))
	seconds=$(($timeDiff % 60))
}

# 2- Snapshot creation
function create_snapshot () {
	$LVCREATE --size $3G --snapshot --name $1-SNAPSHOT $2;
}

# 3- File and applications backups
function create_gzip () {
	if [ -d $backup_destination/$2 ]; then
		echo $dir_exists;
	else
		$MKDIR -p $backup_destination/$2;
	fi
		$DD if=$1  bs=$block_size | $GZIP -c > $backup_destination/$2/$2_$dateFile.img.gz
		$MD5SUM $backup_destination/$2/$2_$dateFile.img.gz > $backup_destination/$2/$2_$dateFile.checksum

	if [ -f $backup_destination/$2/$2_$dateFileBefore.img.gz ]; then
		# Old files rotation 
		$RM $backup_destination/$2/$2_$dateFileBefore.img.gz;
		$RM $backup_destination/$2/$2_$dateFileBefore.checksum;
	else 
		echo $nothing;
	fi
}

# 5-Iteration through LVM volumes
for i in `get_lvs`; do
	startTimeLVM=`date '+%s'`
	
	echo -e "\n ######################### `get_lvs_name $i` #########################"
   
   	# Volumes retrieval
   	echo -e "\n STEP 1 :Snapshot creation"
   	create_snapshot `get_lvs_name $i` $i $snapshot_max_size 
	
   	echo -e "\n STEP 2 : Gzip creation"
   	create_gzip $i-SNAPSHOT `get_lvs_name $i`
     
   	echo -e "\n STEP 3 : Snapshot deletion "
	sleep 1;
   	$LVREMOVE -f $i-SNAPSHOT

	#Time accounting per volume
	time_accounting `date '+%s'` $startTimeLVM
	
	# Mail notification creation
	backup_size=`$DU -h $backup_destination/\`get_lvs_name $i\` | $CUT -f 1`
	echo -e "$backup_destination/`get_lvs_name $i`- $hours h $minutes m and $seconds seconds. Size - $backup_size" >> $email_tmp_file	
done

# 6- Mail notification
if [ $enable_mail_notification -eq 0 ]; then
	echo $mailnotifications_disabled
else
	time_accounting `date '+%s'` $startTime
	echo -e "---------------------------------------" >> $email_tmp_file
	echo -e "Total backups size - `$DU -sh $backup_destination | $CUT -f 1`" >> $email_tmp_file
	echo -e "Total execution time - $hours h $minutes m and $seconds seconds" >> $email_tmp_file
	echo -e "To : $recipient \nSubject : The EBS volumes have been backed up in $hours h and $minutes mn the $dateMail \n`$CAT $email_tmp_file`" | $SENDMAIL $email_recipient
fi

rm $email_tmp_file
