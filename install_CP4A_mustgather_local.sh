#!/bin/bash
#------------------------------------------
# 
# Usage: install_CP4A_must-gather_local.sh -U <OpenShift username> -P <OpenShift password> -s <OpenShift API server> -u <registry username> -p <registry password> 
#        -r <registry host/IP> -n <namespace> -f <folder path to cp-mustgather-local.4.5.16.tar.gz> [ -l loglevel -c clean -d dry-run -I Integrated_OCP_registry]
#
# Description: Installs cp-mustgather-local.4.5.16 container image to run must-gather in air-gap or disconnected environment
#
#  After cp-mustgather-local installed,
#  run must-gather collector with modified syntax as follows:
#   $ oc adm must-gather --image=localhost/$ns/must-gather:4.5.16 -- gather -n $ns,ibm-common-services
#
# Dependencies: cp-mustgather-local.4.5.16.tar.gz
#
# See Usage() for details
#
#----------------------------------------------
NULL=/dev/null
sp="echo "" "
red='\e[31m'
clear='\e[0m'
imageTag="4.5.16"

# Print usage details if required parameters not validated 
Usage()
{
   $sp
   echo "usage: install_CP4A_must-gather_local.sh -U <OpenShift username> -P <OpenShift password> -s <OpenShift API server> -u <registry username> -p <registry password> -r <registry host/IP> -n <namespace> -f <folder path to cp-mustgather-local.$imageTag.tar.gz> [ -l loglevel -c clean -d dry-run -I use_OCP_integrated_registry] "
   $sp
   echo "Required parameters:"
   echo -e "\t-U OpenShift username"
   echo -e "\t-P OpenShift password"
   echo -e "\t-s OpenShift API server"
   echo -e "\t-u Registry username"
   echo -e "\t-p Registry password"
   echo -e "\t-r Registry server"
   echo -e "\t-n namespace to install must-gather"
   echo -e "\t-f dir path of cp-mustgather-local.$imageTag.tar.gz, default is ."
   $sp
   echo "Optional parameters:"
   echo -e "\t-l logging for debugging loglevel [values: debug | info(default) | error]"
   echo -e "\t-c clean install, if true  remove existing image from registry before installing, default=false"
   echo -e "\t-d dry-run, If true only print the cmds that would be executed, without executing or modifying system, default=false"
   echo -e "\t-I Use Integrated OCP registry, default=false. If true, -u <registry username> -p <registry password> are ignored"
   $sp
   echo "example:"
   echo "install_CP4A_mustgather_local.sh -U kubeadmin -P  passw0rd -s https://api.ocp1.fyre.ibm.com:6443 -u jfrog_user1 -p jfrog_passw0rd -r artifactory_dev.fyre.ibm.com  -n cp2103ns -f $HOME/Downloads "
   exit 1 # Exit script after printing Usage
}

# set defaults for Optional args
clean=false
loglevel=info
dryRun=false
mustGatherImagePath="."
useOCPregistry=false

while getopts "U:P:s:u:p:r:n:f:c:d:I:l:" opt
do
   case "$opt" in
      # -- Required parameters --
      U ) kubeuser="$OPTARG" ;;
      P ) kubeuser_pw="$OPTARG" ;;
      s ) apiURL="$OPTARG" ;;
      u ) reguser="$OPTARG" ;;
      p ) reguser_pw="$OPTARG" ;;
      r ) registry="$OPTARG" ;;
      n ) ns="$OPTARG" ;;
      f ) mustGatherImagePath="$OPTARG" ;;

      # -- Optional parameters --
      c ) clean="$OPTARG" ;;
      d ) dryRun="$OPTARG" ;;
      I ) useOCPregistry="$OPTARG" ;;
      l ) loglevel="$OPTARG" ;;
      ? ) Usage ;; # Print Usage in case parameter is non-existent
   esac
done

if [[ $loglevel == "debug" ]] ; then
  echo "$0 -U $kubeuser -P $kubeuser_pw -s $apiURL -u $reguser -p $reguser_pw -r $registry -n $ns -f $mustGatherImagePath -l $loglevel -c $clean -d $dryRun -I $useOCPregistry"
fi

# Validate Required parameter, print Usage if not met  
if [ "$useOCPregistry" = "true" ] ; then
 echo "using OpenShift Integrated Registry"
 if [ -z "$kubeuser" ] || [ -z "$kubeuser_pw" ] || [ -z "$apiURL" ] || \
    [ -z "$registry" ] || [ -z "$ns" ] || [ -z "$mustGatherImagePath" ] ; then Usage ; fi
elif [ -z "$kubeuser" ] || [ -z "$kubeuser_pw" ] || [ -z "$apiURL" ] || [ -z "$reguser" ] || \
     [ -z "$reguser_pw" ] || [ -z "$registry" ] || [ -z "$ns" ] || [ -z "$mustGatherImagePath" ] ; then Usage 
fi

cluster_login=$(oc login -u $kubeuser -p $kubeuser_pw $apiURL  | grep "Login successful.")
if [[ $cluster_login == "Login successful." ]] ; then
  echo "OpenShift Cluster login: $cluster_login"
else
  echo -e $red"Unable to authenticate to $apiURL with credentials: -u $kubeuser -p $kubeuser_pw"$clear  
  echo "You must be logged into the cluster to run install_CP4A_mustgather_local.sh "
  exit
fi

# If OCP_integrated_registry specified, set registry credentials to OCP_user/oc whoami -t
if [[ $useOCPregistry == "true" ]] ; then
 reguser=$kubeuser
 reguser_pw=$(oc whoami -t)
fi

registry_login=$(sudo podman login -u $reguser -p $reguser_pw  $registry)
if [[ $registry_login == "Login Succeeded!" ]] ; then
  echo "Docker registry login: $registry_login"
else
  echo -e $red"Unable to authenticate to Docker container registry  $registry with credentials: -u $reguser -p $reguser_pw"$clear 
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

if [[ ! -f "$mustGatherImagePath/cp-mustgather-local.$imageTag.tar.gz" ]] ; then
  echo -e $red"cp-mustgather-local.$imageTag.tar.gz not found in location: $mustGatherImagePath  enter valid path for cp-mustgather-local.$imageTag.tar.gz"$clear  
  exit
fi

if [[ $dryRun == "true" ]] ; then
 runCmdMsg="Dry-run mode, running cmd:"
else
 runCmdMsg="running cmd:"
fi

echo "installing $mustGatherImagePath/cp-mustgather-local.$imageTag.tar.gz ..."
if [[ $clean == "clean" ]] ; then
  cmd=$(sudo  podman images -a --log-level $loglevel | grep must-gather | awk '{print $3}'  | xargs sudo podman rmi -fi )
  echo $runCmdMsg $cmd
  if [[ $dryRun == "false" ]] ; then $cmd ; fi
fi

cmd=$(sudo podman image load --input $mustGatherImagePath/cp-mustgather-local.$imageTag.tar.gz --log-level $loglevel)
# echo $runCmdMsg $cmd
# if [[ $dryRun == "false" ]] ; then $cmd ; fi
sudo podman image load --input $mustGatherImagePath/cp-mustgather-local.$imageTag.tar.gz

# cmd=$(sudo podman images --log-level $loglevel | grep none| awk '{print $3}') 
# echo $runCmdMsg $cmd
# if [[ $dryRun == "false" ]] ; then imageID=$cmd ; fi
imageID=$(sudo podman images --log-level $loglevel | grep none| awk '{print $3}')

# cmd=$(sudo podman tag $imageID $registry/$ns/must-gather:$imageTag)
# echo $runCmdMsg $cmd
# if [[ $dryRun == "false" ]] ; then $cmd ; fi
echo "sudo podman tag $imageID $registry/$ns/must-gather:$imageTag"
sudo podman tag $imageID $registry/$ns/must-gather:$imageTag

# cmd=$(sudo podman push  --creds $reguser:$reguser_pw $registry/$ns/must-gather:$imageTag)
# echo $runCmdMsg $cmd
# if [[ $dryRun == "false" ]] ; then $cmd ; fi
echo "sudo podman push  --creds $reguser:$reguser_pw $registry/$ns/must-gather:$imageTag"
sudo podman push  --creds $reguser:$reguser_pw $registry/$ns/must-gather:$imageTag

echo "must-gather container installed into $registry/$ns/must-gather:$imageTag"
echo ""
 oc adm must-gather -- gather -m automationfoundation -n cp2103ns,ibm-common-services 
# echo "usage: oc adm must-gather --image=localhost/$ns/must-gather:$imageTag -- gather -n $ns,ibm-common-services"
