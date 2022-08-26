#!/bin/bash
#
# login_kube.sh
#
# 1) oc login to OpenShift cluster as kubeadmin
# 2) podman login to local container registry as kubeadmin
#------------
#
if [[ $USER == "root" ]] ; then
 echo "root access not permitted, login as crcuser and try again"
 exit 0
fi

if [[ !  $SERVICE_RUNNING ]] ; then
 echo "OpenShift cluster is not running or there is an issue logging into cluster"
 echo "try logging out crcuser from VNC and all RHEL shells, and log back in, if issue persists, run cmd: crc_reboot"
 exit 0
fi

oc login -u $kubeuser -p $kubeuser_pw $apiServer &> /dev/null 2>&1 

# login to local registry
export registry_pw=$(oc whoami -t)
sudo podman login  --authfile $REGISTRY_AUTH_FILE  --cert-dir $certDir -u $kubeuser  -p  $registry_pw $registry  &> /dev/null 2>&1

# login to IBM Container Registry, if connected to internet
# if  isOnline.sh 
# then 
# sudo podman login cp.icr.io
# fi
