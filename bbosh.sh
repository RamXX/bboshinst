#!/bin/bash
# Installs binary BOSH on OpenStack
# Background on binary BOSH: https://blog.starkandwayne.com/2014/07/10/resurrecting-bosh-with-binary-boshes/
#
# Pre-requisites:
#
# apt-get install bzr jq golang
# export GOPATH=$HOME/go && export PATH=$PATH:$GOPATH/bin:
# go get github.com/bronze1man/yaml2json 
# BOSH CLI needs to be installed of course.

# Functions first
# fix_uuid: Replaces the existing director-uuid for the one specified in the second parameter
fix_uuid ()
{
	cat $1 | gawk "BEGIN {FS=\":\"}{ if (\$1 == \"director_uuid\") {print \"director_uuid: \" \"$2\";} else { print \$0;} }" > /tmp/tmpyaml
    mv /tmp/tmpyaml $1
}

# deploy_bosh: deploys BOSH
deploy_bosh () 
{
    local director_uuid=$(bosh status --uuid)
	fix_uuid $1 $director_uuid 
	bosh deployment $1
	yes yes | bosh deploy
}

# Stop monit agents in VM
stop_agents ()
{
	echo $COWPASS | ssh -o StrictHostKeyChecking=no -i $keyfile -t vcap@$1 bash -c "'sudo -S /var/vcap/bosh/bin/monit stop all'"
}

# Start monit agents in VM
start_agents ()
{
	echo $COWPASS | ssh -o StrictHostKeyChecking=no -i $keyfile -t vcap@$1 bash -c "'sudo -S /var/vcap/bosh/bin/monit start all'"
}

# Delete store
delete_store ()
{
	echo $COWPASS | ssh -o StrictHostKeyChecking=no -i $keyfile -t vcap@$1 bash -c "'sudo -S rm -rf /var/vcap/store/*'"
}

#Download store
download_store ()
{
	echo $COWPASS | ssh -o StrictHostKeyChecking=no -i $keyfile -t vcap@$1 bash -c "'sudo -S tar -pczf - /var/vcap/store/*'" > /tmp/storefile.tar.gz
}

#Upload store
upload_store ()
{
	scp -o StrictHostKeyChecking=no -i $keyfile /tmp/storefile.tar.gz vcap@$1:/home/vcap/storefile.tar.gz
	echo $COWPASS | ssh -o StrictHostKeyChecking=no -i $keyfile -t vcap@$1 bash -c "'sudo -S tar -C / -pxzf /home/vcap/storefile.tar.gz'" 
	echo $COWPASS | ssh -o StrictHostKeyChecking=no -i $keyfile -t vcap@$1 bash -c "'sudo -S rm -f /home/vcap/storefile.tar.gz'" 
}

# Add resurrection
add_resurrection ()
{
	sed 's/resurrector_enabled: false/resurrector_enabled: true/' < $1 > /tmp/temp_manifest.yml 
    mv /tmp/temp_manifest.yml $1

	bosh deployment $1
	bosh -n deploy
}

###########################################
##           MAIN starts here            ##
###########################################
# set -x
# Change if using different
export BOSH_USER='admin'
export BOSH_PASSWORD='admin'
export COWPASS='c1oudc0w'

if [[ -z "$OS_USERNAME" ]] ; then
	echo "Source your OpenStack openrc.sh file first"
	exit 1
fi

stemcell=$1
bosh_release=$2
micro_manifest=$3
manifest1=$4
manifest2=$5
keyfile=$6

if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" || -z "$6" ]] ; then
	echo "usage: bbosh <stemcell> <release tarball> <microbosh manifest> <manifest 1> <manifest 2> <PEM keyfile>"
	exit 1
fi

# Obtain IP addresses from manifests
microbosh_ip=$(cat $micro_manifest | yaml2json | jq -r .network.ip)
primary_ip=$(cat $manifest1 | yaml2json | jq -r .properties.director.address)
meta_ip=$(cat $manifest2 | yaml2json | jq -r .properties.director.address)

# Cleanup know_hosts so we can ssh later
ssh-keygen -f "$HOME/.ssh/known_hosts" -R $microbosh_ip &> /dev/null
ssh-keygen -f "$HOME/.ssh/known_hosts" -R $primary_ip &> /dev/null
ssh-keygen -f "$HOME/.ssh/known_hosts" -R $meta_ip &> /dev/null

# First we deploy MicroBOSH, target it, and upload the required files
bosh micro deployment $micro_manifest 
yes yes | bosh micro deploy $stemcell
bosh target $microbosh_ip micro
bosh upload release $bosh_release
bosh upload stemcell $stemcell

# Next, we prepare the deployment manifest for the primary BOSH and deploy
deploy_bosh $manifest1 
bosh target $primary_ip "primary" 
bosh upload release $bosh_release
bosh upload stemcell $stemcell

# Now we deploy and target meta-BOSH
deploy_bosh $manifest2 
bosh target $meta_ip "meta" 

# We now stop agents everywhere
stop_agents $meta_ip
stop_agents $primary_ip
stop_agents $microbosh_ip
sleep 30

# Cleanup meta-BOSH's store and download the store from microbosh
# to this VM, then uploads it to the meta.
delete_store $meta_ip
download_store $microbosh_ip 
upload_store $meta_ip

# Crossing fingers that everything worked out
# we now start the agents in the meta
start_agents $meta_ip
sleep 60

# We now target the meta and attempt to fix the primary
bosh target $meta_ip
bosh deployment $manifest1
echo -e "3\nyes" | bosh cck

# If everything went well, we can now target our primary and it should be functional
# Let's add now some resurrection to the primary.
add_resurrection "$manifest1"

# We now target the primary going forward and do the same with meta
bosh target primary
add_resurrection "$manifest2"

# we finish with the status for the primary BOSH and cleanup variables.
bosh status

unset BOSH_USER
unset BOSH_PASSWORD
unset COWPASS
