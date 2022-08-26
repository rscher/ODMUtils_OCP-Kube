#!/bin/bash
#
# displayInfo.sh  
#

hostName=$(hostname -f)
IPaddr=$(hostname -i)

export SERVICE_RUNNING=$(pgrep -x "qemu-kvm") 
echo $SERVICE_RUNNING > ~/.SERVICE_RUNNING 

if [[ $SERVICE_RUNNING ]] ; then
 if [[ $(helm ls -A -q) ]] ; then
  echo "Helm Charts installed: "
  helm ls -A
  echo ""
  export odm8110installed=$(helm ls -A -q | grep 8110)
  export odm8105installed=$(helm ls -A -q | grep 8105)
  export cp2201installed=$(helm ls -A -q | grep cp2201)

  if [[ $odm8110installed ]] ; then
   echo "ODM pods running in namespace: $odm8110installed"
   kubectl get pods -n $odm8110installed --ignore-not-found=true 
  fi
  echo ""
  
  if [[ $odm8105installed ]] ; then
   echo "ODM pods running in namespace: $odm8105installed"
   kubectl get pods -n $odm8105installed  --ignore-not-found=true 
  fi                     
 echo ""

 if [[ $cp2201installed ]] ; then
   echo "ODM pods running in namespace: $cp2201installed"
   kubectl get pods -n $cp2201installed  --ignore-not-found=true | grep  odm-decision
  fi
 else
  echo "No Helm charts installed."
 fi 
 if 
else
 echo "Cluster not running on host: $hostName IP: $IPaddr."
 unset odm8105installed
 unset odm8110installed
 unset cp2201installed 
fi

 exportPodNames.sh
 getODM-URLs.sh

echo "______________________"
echo "To view this info from shell, run cmd: displayInfo"
echo "To start menu from shell, run cmd: menu " 
echo "To start or view vnc session, run cmd: startvnc"
