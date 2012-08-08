#!/bin/bash
# Shell : Bash
# Description : Small ressources gatherer script
# Author : razique.mahroua@gmail.com
# Current version : Version 00

# 		Revision note    
# V00 : Initial version

# 		Usage
# chmod +x SCR_5025_$version_NUAC-ressources-gatherer.sh
# ./SCR_5027_$version_NUAC-ressources-gatherer.sh

# Binaries
	CAT=/bin/cat
	HOSTNAME=/bin/hostname
	CPUINFO=/proc/cpuinfo
	IFCONFIG=/sbin/ifconfig
	UNAME=/bin/uname
	DMESG=/bin/dmesg
	FDISK=/sbin/fdisk
	CUT=/usr/bin/cut
	WC=/usr/bin/wc
	GREP=/bin/grep
	SORT=/usr/bin/sort
	HEAD=/usr/bin/head
	TAIL=/usr/bin/tail
	SED=/bin/sed
	AWK=/usr/bin/awk
	XARGS=/usr/bin/xargs
	PRINTF=/usr/bin/printf

echo -e -n "• Hostname:\t"
$HOSTNAME

echo -e -n "• CPU Model:\t"
$CAT $CPUINFO | $GREP "model name" | $HEAD -1 | $CUT -d ":" -f 2 | $SED -e 's/^[ \t]*//'

echo -e -n "• CPU count:\t"
	echo -e "$(( `cat $CPUINFO | grep "processor" | $TAIL -1 | $CUT -d ":" -f 2 | $SED -e 's/^[ \t]*//'` +1))"

echo -e -n "• CPU freq :\t"
echo -e "`cat $CPUINFO | grep "MHz" | $HEAD -1 | $CUT -d ":" -f 2 | $SED -e 's/^[ \t]*//'` Mhz"

echo -e -n "• Memory :\t"
echo "`$GREP "MemTotal" /proc/meminfo | $AWK '{print $2}'`/1048576" | bc -l | $XARGS $PRINTF "%1.3f"" GB"
echo

echo -e -n "• OS Release:\t"
$UNAME -r

echo -e -n "• Disks :\t"
echo
echo -e "\t `$FDISK -l | $GREP "Disk" | $GREP -v "identifier" | $CUT -d "," -f 1`"



echo -e -n "• Network Ifaces:\t"
echo
for i in $( $IFCONFIG |  $CUT -d " " -f 1 | $GREP -v ^$ ); do
	echo -e "\t $i : `$IFCONFIG $i | $GREP "inet" | $GREP -v "inet6" | $CUT -d ":" -f 2 | $CUT -d " " -f 1` "
done
echo


