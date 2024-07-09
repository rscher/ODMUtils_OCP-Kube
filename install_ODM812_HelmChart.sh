#!/bin/bash
# ------------------------
#  install_8120_K8S.sh
#
#  Script installs the latest ODM on Kubernetes Helm chart to namespace odm8120
#  as kubeadmin/ privileged-user into OpenShift cluster.
#  uses DB2 : DCDB812 , RESDB812
#  Tag: 8.12.0.1-IF005-amd64
#
# -------------------------
#
loglevel="info"

# source env sets all env vars used, such as $db_user $db_password, $REGISTRY_AUTH_FILE
$sourceEnv
# $initBash

export odm_ns="odm8120" 

# location of Helm chart archive expanded, change per your location
INSTALL_DIR=$CRC_HOME/ODM8121_K8S

CUR_DIR=$(pwd)
TIMESTAMP=`date "+%Y-%m-%d%H%M%S"`
mkdir -p $INSTALL_DIR/logs/
LOG_FILE=$INSTALL_DIR/logs/install_8121-IF005_K8S-$TIMESTAMP.log ; touch $LOG_FILE

echo "Installing ODM 8.12.0.1-IF005 ... "
echo "install log: $LOG_FILE"
pushd $INSTALL_DIR  > $NULL

# create new namespace, comment out if namespace already created 
oc new-project $odm_ns

oc project $odm_ns
# creates privileged OpenShift security policy for namespace and default, uncomment if needed 
# oc  create -f ibm-privileged-scc.yaml --validate=false  >> $LOG_FILE
# oc adm policy add-scc-to-user ibm-privileged-scc -z default  >> $LOG_FILE
# oc adm policy add-scc-to-user ibm-privileged-scc -z $odm_ns  >> $LOG_FILE
# oc adm policy add-scc-to-group ibm-privileged-scc system:serviceacounts:$odm_ns  >> $LOG_FILE

#  create db secret for external db used in values.yaml
kubectl  create secret generic odm-db-secret --from-literal=db-user=$db_user --from-literal=db-password=$db_password   >> $LOG_FILE

# secret for local container registry access (used only for OpenShift local clusters), uncomment as needed
# oc create secret generic auth --from-file=.dockerconfigjson=$REGISTRY_AUTH_FILE --type=kubernetes.io/dockerconfigjson  >> $LOG_FILE

# pass argument 'noImageLoad' to this script to bypass container pull, speeds up install time, useful for dev/debug
if [ "$1" != "noImageLoad" ] ; then
 loglevel=info
 #
 # REGISTRY_AUTH_FILE="~/.podman/config.json" 
 # If not using REGISTRY_AUTH_FILE, remove --authfile $REGISTRY_AUTH_FILE from podman pull
 #
 sudo podman pull --authfile $REGISTRY_AUTH_FILE cp.icr.io/cp/cp4a/odm/odm-decisioncenter:8.12.0.1-IF005-amd64
 sudo podman pull --authfile $REGISTRY_AUTH_FILE cp.icr.io/cp/cp4a/odm/odm-decisionserverruntime:8.12.0.1-IF005-amd64
 sudo podman pull --authfile $REGISTRY_AUTH_FILE cp.icr.io/cp/cp4a/odm/odm-decisionserverconsole:8.12.0.1-IF005-amd64
 sudo podman pull --authfile $REGISTRY_AUTH_FILE cp.icr.io/cp/cp4a/odm/odm-decisionrunner:8.12.0.1-IF005-amd64

 # Enable image lookup in the imagestream (is) which allows is as the source of images without having to provide the full URL to the internal registry. applies only to OpenShift K8S clusters
 oc set image-lookup odm-decisioncenter 
 oc set image-lookup odm-decisionserverconsole 
 oc set image-lookup odm-decisionserverruntime 
 oc set image-lookup odm-decisionrunner 
fi

# Install Helm chart with marked up values.yaml for all ODM properties
# replace Helm chart ibm-odm-prod-23.2.9.tgz with latest version from 
# https://github.com/IBM/charts/blob/master/repo/ibm-helm/ibm-odm-prod-23.2.9.tgz
#
helm install $odm_ns --set customization.runAsUser=''  -f values.yaml $INSTALL_DIR/charts/ibm-odm-prod-23.2.9.tgz
echo "Installing Helm chart ibm-odm-prod-23.2.9, waiting for ODM812 pods to be Ready ..."

# 'kubectl wait' waits for the condition when DC pod is in Ready state to complete the install-DC pod takes longest to start
decisioncenter_podname=$(kubectl get pods | grep decisioncenter | awk '{print $1}')
# then wait until decisioncenter pod is Ready
kubectl wait --for=condition=Ready pod/"$decisioncenter_podname" --timeout=-30s

#
# To uninstall Helm chart run:  helm uninstall $odm_ns
# 
popd   > $NULL
