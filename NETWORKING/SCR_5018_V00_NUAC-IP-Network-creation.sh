#!/bin/bash

# Shell : Bash
# Description : Small IPv4 Calculator
# Author : razique.mahroua@gmail.com
# Actual version : Version 00

# 		Revision note    
# V00 : Initial version

# This script can be used to create a network range. It calculates the broadcast and all the usables IP for a provided range, then generates the command lines to paste !
	
# 		Usage
# chmod +x SCR_5018_$version_NUAC-IP-Network-creation.sh
# ./SCR_5018_$version_NUAC-IP-Network-creation.sh "192.168.0.1/24"           

# Binaries
	CUT=/usr/bin/cut
	IP=/bin/ip
	IFCONFIG=/sbin/ifconfig
# Settings
	DEBUG=0
	RANGE_T0_CREATE="$1"
	INTERFACE_TO_USE="$2"
	IP_VALIDATION=0
	MASQ_VALIDATION=0

if [ $#  -ne "2" ]; then 
	echo "USAGE : $0 NETWORK-RANGE/CIDR DEVICE, e.g $0 192.168.1.0/24 eth0"
	exit 0;
fi

function ip_validation() {
	# We first extract the adresses and the netmask 
	NETWORK=`echo $1 | cut -f 1 -d "/"`
	CIDR_MASQ=`echo $1 | cut -f 2 -d "/"`

 	# We validate the IP adress	
	if ! [[ $NETWORK =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		echo "This does not seem to be a valid IP, please submit a correct ipv4 address."
		exit 0
	else
		IP_VALIDATION=1
	fi

	# We then check the netmask
	if ! [[ $CIDR_MASQ =~ ^[0-9]+$ ]]; then
		echo "This does not seem to be a valid CIDR notation, try again."
		exit 0;
	else
		if [[ $CIDR_MASQ -gt "32" || $CIDR_MASQ -lt 1 ]]; then
			echo "This does not seem to be a valid CIDR notation, try again."
			exit 0;
		else
			MASQ_VALIDATION=1
		fi
	fi

	# We are now ready to initialize all the values
	if [[ $IP_VALIDATION -eq "1" && $MASQ_VALIDATION -eq 1 ]]; then
		NETWORK_SEGMENT=`echo $NETWORK | $CUT -f 1,2,3 -d "."`
		HOST_SEGMENT=`echo $NETWORK | $CUT -f 4 -d "."`
		AVAILABLE_IPS=$((2**(32-$CIDR_MASQ)))
		AVAILABLE_HOSTS=$(($AVAILABLE_IPS-2))
		FIRST_HOST_IP=$(($HOST_SEGMENT+1))
		BROADCAST_IP=$(($HOST_SEGMENT+$((AVAILABLE_IPS-1))))
		LAST_HOST_IP=$(($BROADCAST_IP-1))
		FULL_FIRST_HOST_IP=$NETWORK_SEGMENT.$FIRST_HOST_IP
		FULL_LAST_HOST_IP=$NETWORK_SEGMENT.$LAST_HOST_IP
		FULL_BROADCAST_IP=$NETWORK_SEGMENT.$BROADCAST_IP
		GATEWAY_IP=$NETWORK_SEGMENT.$(($HOST_SEGMENT+1))
	fi
}

function interface_validation() {
	INTERFACE=$1
	INTERFACE_EXISTS=`$IFCONFIG | grep $INTERFACE | wc -l`
	if [ $INTERFACE != "lo" ]; then 
		if [ $INTERFACE_EXISTS -ne "1" ]; then
			echo "Non existent interface, try again."
			exit 0;
		fi
	fi
}

# Let's validate the input
interface_validation $INTERFACE_TO_USE
ip_validation $RANGE_T0_CREATE

echo -e "\t Interface to use : $INTERFACE"
echo -e "\t Network : $NETWORK"
echo -e "\t CIDR Masq : $CIDR_MASQ"
echo -e "\t Number of available IP hosts : $AVAILABLE_HOSTS"
echo -e "\t First Host IP : $FULL_FIRST_HOST_IP"
echo -e "\t Last Host IP : $FULL_LAST_HOST_IP"
echo -e "\t Broadcast IP : $FULL_BROADCAST_IP"

if [ $DEBUG -eq 1 ]; then
	echo -e "\n** DEBUG MODE ENABLED **"
		echo -e "\t NETWORK_SEGMENT : $NETWORK_SEGMENT"
		echo -e "\t HOST_SEGMENT : $HOST_SEGMENT"
		echo -e "\t AVAILABLE_IPS : $AVAILABLE_IPS"
		echo -e "\t AVAILABLE_HOSTS : $AVAILABLE_HOSTS" 
		echo -e "\t FIRST_HOST_IP : $FIRST_HOST_IP"
		echo -e "\t LAST_HOST_IP : $LAST_HOST_IP"
		echo -e "\t BROADCAST_IP : $BROADCAST_IP"
		echo -e "\t FULL_FIRST_HOST_IP : $FULL_FIRST_HOST_IP" 
		echo -e "\t FULL_LAST_HOST_IP : $FULL_LAST_HOST_IP" 
		echo -e "\t FULL_BROADCAST_IP : $FULL_BROADCAST_IP"
		echo -e "\t GATEWAY_IP : $GATEWAY_IP"		
	echo "** DEBUG MODE **"

else
	echo -e "------------[ cut here ]------------\n"
		for (( i=0; i<$AVAILABLE_HOSTS; i++ )); do
			echo "$IP addr add $NETWORK_SEGMENT.$(($FIRST_HOST_IP+$i))/$CIDR_MASQ dev $INTERFACE broadcast $FULL_BROADCAST_IP"
		done
	echo -e "\n------------[ cut above ]------------"
fi
