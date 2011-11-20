#!/bin/bash

# Shell : Bash
# Description : Dual WAN routing script
# Author : razique.mahroua@gmail.com
# Original author : Robert Kurjata Sep, 2003.
# Actual version : Version 00

# 		Revision note    
# V00 : Initial version

#  		Notes    	
# This script create both routing tables in order to handle dual WAN routing. Simply define your routes, their subnet and the gateway.
# The script creates tables and routing policy accordingly.
	
# 		Usage
# chmod +x SCR_2012_$version_NUAC-Dual-wan-routing.sh
# ./SCR_2012_$version_NUAC-Dual-wan-routing.sh          

# Binaries
	IP=/sbin/ip
	PING=/bin/ping

#Routing
	# IFn - interface name
	# IPn - outgoing IP
	# NMn  - netmask length (bits)
	# GWn - outgoing gateway

# Link 1
	IF1=eth0
	IP1=XX.XX.XX.XX
	NM1=255.255.255.0
	GW1=XX.XX.XX.XX

# Link 2
	IF2=eth2
	IP2=YY.YY.YY.YY
	NM2=255.255.255.0
	GW2=YY.YY.YY.YY

# 1- We remove the old routes
	echo "1- Removing old rules..."
${IP} rule del prio 50 table main
${IP} rule del prio 201 from ${IP1}/${NM1} table 201
${IP} rule del prio 202 from ${IP2}/${NM2} table 202
${IP} rule del prio 221 table 221

	echo "2- Flushing tables"
${IP} route flush table 201
${IP} route flush table 202
${IP} route flush table 221

	echo "3- Removing tables"
${IP} route del table 201
${IP} route del table 202
${IP} route del table 221

# 2- We set the new routes
	echo "4- Setting new routing rules"
	# We delete the main table
${IP} rule add prio 50 table main
${IP} route del default table main

	# We set the new priorities
${IP} rule add prio 201 from ${IP1}/${NM1} table 201
${IP} rule add prio 202 from ${IP2}/${NM2} table 202

${IP} route add default via ${GW1} dev ${IF1} src ${IP1} proto static table 201
${IP} route append prohibit default table 201 metric 1 proto static

${IP} route add default via ${GW2} dev ${IF2} src ${IP2} proto static table 202
${IP} route append prohibit default table 202 metric 1 proto static

# 3- We set the mutipath
	echo "5- Multipath set"
${IP} rule add prio 221 table 221

${IP} route add default table 221 proto static \
            nexthop via ${GW1} dev ${IF1} weight 2\
            nexthop via ${GW2} dev ${IF2} weight 3

${IP} route flush cache

# 4- We make sure both routes work
while : ; do
  ${PING} -c 1 ${GW1}
  ${PING} -c 1 ${GW2}
done