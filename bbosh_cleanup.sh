#!/bin/bash
# Cleanup the Binary BOSH deployment from OpenStack
# Assumes sourcing of the openrc.sh variables
# 
# usage: bbosh_cleanup.sh <microbosh-IP> <primary-IP> <meta-IP>
#
# Global variables

CINDER_WAIT=20 # Seconds to wait before cleaning up Cinder (varies per provider)

microbosh_ip="$1"
primary_ip="$2"
meta_ip="$3"

if [ -z "$1" -o -z "$2" -o -z "$3" ] ; then
	echo 'usage: bbosh_cleanup.sh <microbosh-IP> <primary-IP> <meta-IP>'
	exit 1
fi

# deletes the instances and all left over BOSH files, including logs
rm -rf ~/.ssh/known_hosts bosh-deployments.yml *log ~/.bosh_*
nova delete `nova list | grep 10.10.10.10 | awk 'BEGIN{FS="|"}{print $2}'`
nova delete `nova list | grep 10.10.10.16 | awk 'BEGIN{FS="|"}{print $2}'`
nova delete `nova list | grep 10.10.10.17 | awk 'BEGIN{FS="|"}{print $2}'`

sleep $CINDER_WAIT

# Delete volumes and stemcells
for i in  `cinder list | grep available | awk 'BEGIN{FS="|"}{print $2}'`; do cinder delete $i; done
for i in  `glance image-list | grep BOSH | awk 'BEGIN{FS="|"}{print $2}'`; do glance image-delete $i; done
