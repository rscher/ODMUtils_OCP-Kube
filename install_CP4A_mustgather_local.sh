#!/bin/bash
#
# usage: install_CP4A_mustgather_local.sh $1 $2 $3 $4 $5 $6
# $1=cluster_username
# $2=cluster_password
# $3=cluster_API_URL
# $4=registry
# $5=namespace
# $6=path of must-gather.tar.gz
#
#----------------------------------------------
if [ $# -ne 6 ] ; then
 echo "usage: install_CP4A_mustgather_local.sh <cluster_username> <cluster_password>  <cluster_API_URL> <registry> <namespace> <path to must-gather.tar.gz>"
 echo "example:"
 echo "./install_CP4A_mustgather_local.sh  kubeadmin kubeadmin_pw  https://api.crc.testing:6443   default-route-openshift-image-registry.apps.your_registry.com  odm8110 $HOME" 
 exit
fi

kubeuser=$1
kubeuser_pw=$2
apiURL=$3
registry=$4
ns=$5
mustGatherImagePath=$6
red='\e[31m'
clear='\e[0m'

cluster_login=$(oc login -u $kubeuser -p $kubeuser_pw $apiURL  | grep "Login successful.")
if [[ $cluster_login == "Login successful." ]] ; then
  echo "OpenShift Cluster login: $cluster_login"
else
  echo -e $red"Unable to authenticate to $apiURL with credentials: -u $kubeuser -p $kubeuser_pw"$clear  
  echo "You must be logged into the cluster to run install_CP4A_mustgather_local.sh "
  exit
fi

registry_login=$(sudo podman login -u $kubeuser -p $(oc whoami -t) $registry)
if [[ $registry_login == "Login Succeeded!" ]] ; then
  echo "Docker registry login: $registry_login"
else
  echo -e $red"Unable to authenticate to Docker  $registry with credentials: -u $kubeuser -p $kubeuser_pw"$clear 
  echo "You must be logged into the Docker registry to run install_CP4A_mustgather_local.sh "
  exit
fi

nsValid=$(oc project --short=true $ns)
if [[ $nsValid == $ns ]] ; then
  echo "namespace $ns is valid"
else
  echo -e $red"$ns is not a valid namespace"$clear  
  echo "You must provide a valid namespace to run install_CP4A_mustgather_local.sh "
  exit
 fi

if [[ ! -f "$6/must-gather.tar.gz" ]] ; then
  echo -e $red"must-gather.tar.gz  not found in location: $6 enter valid path for must-gather.tar.gz"$clear  
  exit
fi

echo "installing $6/must-gather.tar.gz ..."
sudo podman image load --input $6/must-gather.tar.gz >  /dev/null
imageID=$(sudo podman images | grep  none | awk '{print $3}' )

sudo podman tag $imageID $registry/$ns/must-gather >  /dev/null
sudo podman push  --creds $kubeuser:$(oc whoami -t) $registry/$ns/must-gather > /dev/null
echo "must-gather container installed into $registry/$ns/must-gather"
echo ""
echo "usage: oc adm must-gather -- gather -m automationfoundation -n $ns"
