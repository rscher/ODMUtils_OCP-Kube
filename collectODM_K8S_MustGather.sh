#!/bin/bash
########################################################
#
#  collectODM_K8S_MustGather.sh
#
#  -ODM on CP4BA/OpenShift/Kubernetes, MustGather script-
#   Collects diagnostics, system info and logs for a specified namespace
#
#  Usage: collectODM_K8S_MustGather.sh  arg1=<namespace>  arg2=[deployment]  [options]
#   Use "collectODM_K8S_MustGather.sh " for command options
#
#   Required:
#    arg1=<namespace>
#
#   Optional:
#    arg2=[ deployment={DC, DSR, DR, DSC} ] 
#      limits collecting MustGather for the specified deployment
#      value must be one of {DC, DSR, DR or DSC} 
#      default value is blank (collects logs for all running ODM pods in namespace)
#
#    example usage:
#     collect logs for all ODM pods running in namespace 'cp2201'
#      $ collectODM_K8S_MustGather.sh cp2201
#
#     collect logs for decisionserverruntime (DSR) deployment running in namespace 'cp2201'
#     if replicaSet has 10 dsr pods running, script will collect MustGather for 10 dsr pods 
#       $ collectODM_K8S_MustGather.sh cp2201 DSR
#
#    Output archive: ./MustGatherODM_K8S.<namespace>.<timestamp>.tar
#
#     System/Cluster/Image Registry Files
#      ./system-info.log (Host/OS info)
#      ./container_images.log  (lists container images with digests from registry)
#      ./kube_config.log (Kubernetes config info , tokens/secrets are redacted)
#      ./<namespace_podname>.log created for each running pod in namespace
#
# -------------------------
#
#    Command Options:
#     --help 
#       (show usage)
#     --javadump  
#       (generate Liberty javacore and heapdump inside the container in addition to pod logs. Does not remove the generated dump from container)
#     --remove_javadumps 
#       (remove all generated javadumps from specified containers - Maintenance task only, does not collect logs or javadumps))
#     --clusterdump
#       (runs 'kubectl cluster-info dump'. Requires cluster admin role, option is CPU intensive and intended for limited usage) 
#
#     example usage of --javadump option:
#      Collect logs and include javadumps (heap and thread dumps) from each DSR pod in 'cp2201' namespace
#      $ collectODM_K8S_MustGather.sh cp2201 DSR --javadump
#
#     example usage of --remove_javadumps option:
#      Removes all generated javadumps from each pod in 'cp2201' namespace
#      $ collectODM_K8S_MustGather.sh cp2201 --remove_javadumps
#
#   Generated tar file contents:
#     Logs/javadumps: archive created for each running pod in namespace
#     ./<namespace>.<podname>.tar
#     ./opt/ibm/wlp/output/defaultServer/heapdump.<timestamp>.phd
#     ./opt/ibm/wlp/output/defaultServer/javacore.<timestamp>.txt
#
#  Note: If there are no running ODM containers, 
#        script will collect System/Cluster/Image Registry Info only
#
######################################################################

unset dbserver
unset dcPods
unset dsrPods
unset drPods
unset dscPods
unset deployment

unset cli_cmd
unset TEMP_FOLDER
unset CUR_DIR
unset ns
unset sudoStr
unset javadumps
unset remove_javadumps
unset clusterdump
unset exitMode

CUR_DIR=$(pwd)
TEMP_FOLDER="$HOME/.tmp"
TIMESTAMP=`date "+%Y%m%d.%H%M%S"`
red='\e[31m' ; clear='\e[0m'
DEV_NULL=/dev/null

#---cmds----
validate_ns="kubectl get ns $1 -o name  --ignore-not-found=true | grep $1 "
wlpServerPathContainer=/opt/ibm/wlp/output/defaultServer
wlpServerCmdContainer=/liberty/wlp/bin/server

dbserver="dbserver"
dsrPods="decisionserverruntime"
dcPods="decisioncenter"
drPods="decisionrunner"
dscPods="decisionserverconsole"

# ----- functions -------
function getPodLogs()
{
 pods=$(kubectl get pods --field-selector=status.phase=Running | grep $deployment | gawk '{print $1}')
 for pod in $pods
 do
  if [[ $remove_javadumps == "true" ]] ; then
   echo "removing all existing javadumps from pod/$pod in deployment/$deployment ..."
   heapdumps=$(kubectl exec -n $ns $pod -- ls -l $wlpServerPathContainer/ | grep heapdump | gawk '{ print $9 }')
   javacores=$(kubectl exec -n $ns $pod -- ls -l $wlpServerPathContainer/ | grep javacore | gawk '{ print $9 }')
   files=$(echo $javacores $heapdumps)
   for file in $files
   do
      kubectl exec -n $ns $pod -- rm -f $wlpServerPathContainer/$file
   done
  elif [[ $javadumps == "true" ]] ; then
   echo "Generating javadumps for pod/$pod in deployment/$deployment ..."
   kubectl exec -n $ns $pod -- $wlpServerCmdContainer javadump defaultServer --include=heap,thread >> $TEMP_FOLDER/javadump.$TIMESTAMP.log
   kubectl exec -n $ns $pod -- tar cf  - $wlpServerPathContainer > $TEMP_FOLDER/$pod.tar
   echo "Collecting logs for pod/$pod in deployment/$deployment ..."
   kubectl describe pod $pod  &> ${TEMP_FOLDER}/describe-$pod.log
   kubectl logs $pod  &> ${TEMP_FOLDER}/$pod.log
  else
   echo "Collecting logs for pod/$pod in deployment/$deployment  ..."
   kubectl describe pod $pod  &> ${TEMP_FOLDER}/describe-$pod.log
   kubectl logs $pod  &> ${TEMP_FOLDER}/$pod.log
  fi
 done
}

function getODMPodLogs
{
if [[ ! "$deployment" ]] ; then
  declare -a namespace=($dsrPods $dcPods $drPods $dscPods)
   for deployment in ${namespace[@]}
  do
   getPodLogs $deployment
  done
else
  getPodLogs $deployment
fi
}


function separator
{
 echo "_________________________________________"  &>> ${TEMP_FOLDER}/system-info.log
 echo ""  &>> ${TEMP_FOLDER}/system-info.log
}

function getSystemInfo
{
timestamp=`date "+%Y-%m-%d-%H%M%S"`
echo "Collecting system info on $timestamp:" | tee -a ${TEMP_FOLDER}/system-info.log
echo "hostname=$(hostname -f) ip=$(hostname -i), user=$USER"  &>> ${TEMP_FOLDER}/system-info.log
id $USER  &>> ${TEMP_FOLDER}/system-info.log

separator

echo "os-release:" &>> ${TEMP_FOLDER}/system-info.log
cat /etc/os-release  &>> ${TEMP_FOLDER}/system-info.log

separator

# Kubernetes and OpenShift version info
echo "Kubernetes version:" &>> ${TEMP_FOLDER}/system-info.log
kubectl version  &>> ${TEMP_FOLDER}/system-info.log
if [[ $clusterdump == "true" ]] ; then
  echo "running 'kubectl cluster-info dump' ..."
  kubectl cluster-info dump &> ${TEMP_FOLDER}/kube_cluster_dump.log
  echo "kubectl cluster-info dump output saved to kube_cluster_dump.log in MustGather tar file"
fi
kubectl config view &>  ${TEMP_FOLDER}/kube_config.log
# check for OpenShift
if command -v "oc" &> $DEV_NULL
then
 echo "OpenShift version:" &>> ${TEMP_FOLDER}/system-info.log
 oc version  &>> ${TEMP_FOLDER}/system-info.log
fi
separator

# container image and runtime info
if [ $USER != "root" ] ;  then  sudoStr="sudo" ; fi
if command -v "podman"  &> $DEV_NULL
then
 cli_cmd="$sudoStr podman"
elif command -v "docker"  &> $DEV_NULL
then
 cli_cmd="$sudoStr docker"
fi
 echo "Container runtime info:" &>> ${TEMP_FOLDER}/system-info.log
${cli_cmd} version  &>> ${TEMP_FOLDER}/system-info.log
${cli_cmd} info  &>> ${TEMP_FOLDER}/system-info.log
${cli_cmd} images --digests &> ${TEMP_FOLDER}/container_images.log

if command -v "skopeo" &> $DEV_NULL
then
 skopeo -v &>> ${TEMP_FOLDER}/system-info.log
fi
separator

echo "Helm info:" &>> ${TEMP_FOLDER}/system-info.log
helm version  &>> ${TEMP_FOLDER}/system-info.log
echo "Helm charts deployed:" &>> ${TEMP_FOLDER}/system-info.log
helm ls -A &>> ${TEMP_FOLDER}/system-info.log
separator
}


function usage_options()
{
 echo " Command Options:"
 echo "  --help      (print help/usage)"
 echo "  --javadump"  
 echo "     (include option to collect javadumps and heapdumps in addition to pod logs. Does not remove the generated dump from containers.)"
 echo "  --remove_javadumps"
 echo "     (remove javadumps from specified containers - Maintenance task only, does not collect new logs or javadumps)"
 echo "  --clusterdump"
 echo "     (runs 'kubectl cluster-info dump'. Requires cluster admin role, option is CPU intensive and intended for limited usage)"
 echo ""
 echo " Examples:"
 echo "  Collect logs and javadumps from all pods running in odm8105 namespace"
 echo "  $ collectODM_K8S_MustGather.sh odm8105 --javadump"
 echo ""
 echo "  Collect logs and javadumps from all decisionserverruntime pods running in cp2103 namespace "
 echo "  $ collectODM_K8S_MustGather.sh  cp2103 DSR --javadump"
 echo ""
 echo "  Remove all generated javadumps from each pod in odm8110 namespace"
 echo "  $ collectODM_K8S_MustGather.sh  odm8110 --remove_javadumps"
 echo ""
}

function usage()
{
echo " usage: collectODM_K8S_MustGather.sh  arg1=<namespace> [arg2=<deployment>] [options]" 
echo "   use 'collectODM_K8S_MustGather.sh  options' for command options"
echo ""
 if [[ $javadumps == "true" ]]  ||  [[ $remove_javadumps == "true" ]] ; then
 usage_options
else
 echo " Required:"
 echo "  arg1=<namespace>"
 echo ""
 echo " [Optional]:"
 echo "  arg2=[ deployment={DC, DSR, DR, DSC} ] "
 echo "    limits collecting MustGather for the specified deployment"
 echo "    value must be one of {DC, DSR, DR or DSC}"
 echo "    default value is blank (collects logs for all running ODM pods in namespace)"
 echo ""
 echo "  examples:"
 echo "   Collect all logs from all ODM pods running in namespace odm81101 "
 echo "   $ collectODM_K8S_MustGather.sh  odm81101"
 echo ""
 echo "   Collect logs for only decisionserverruntime (DSR) pods running in cp2202 namespace"
 echo "   if replicaSet has 10 DSR pods running, will collect 10 DSR log files"
 echo "   $ collectODM_K8S_MustGather.sh  cp2202 DSR"
 echo ""
fi
}

# -----------------
#  --- main ---
# -----------------

if [ ! -d  $TEMP_FOLDER ] ; then
 mkdir -p $TEMP_FOLDER  &> $DEV_NULL
fi

# validate arg1 - required namespace
if [ -z $1 ] || [[ $1 == "--help" ]]   ; then
 exitMode="usage"
elif [[ $1 == "options" ]] ; then
 exitMode="usage"
 javadumps=true
elif [[ $($validate_ns) == "" ]] ; then
 echo -e $red"error: namespace $1 not found in cluster."$clear ; echo "" 
 exitMode="usage"
else
 # namespace is valid, set as current context
 ns=$1
 kubectl config set-context --current --namespace=$ns &> $DEV_NULL
 unset exitMode
fi

# validate arg2 - optional deployment specifier
if [[ $2 != "" ]] ; then
 case $2 in
   DSR) deployment=$dsrPods ;;
   DC)  deployment=$dcPods  ;;
   DSC) deployment=$dscPods ;;
   DR)  deployment=$drPods  ;;
   # javadump options for arg2 when no deployment specifier
   --javadump) javadumps=true ;;
   --remove_javadumps) remove_javadumps=true ;;
   --clusterdump) clusterdump=true ;;
   --help) exitMode="usage" ;;
   *) echo -e $red"error: $2 not a valid option"$clear ; echo "" ; exitMode="usage" ;;
  esac
fi

# parse javadump options when arg2 ia a deployment specifier
if [[ $3 == "--javadump" ]] ; then
 javadumps=true
elif  [[ $3 == "--remove_javadumps" ]] ; then
  unset javadumps
  remove_javadumps=true
elif  [[ $3 == "--clusterdump" ]] ; then
  unset javadumps
  unset remove_javadumps
  clusterdump=true
elif [[ $3 == "--help" ]] ; then
 exitMode="usage"
elif  [[ $3 != "" ]] ; then
 echo "warning: ignoring $3"
 echo ""
fi

if [[ $exitMode == "usage" ]] ; then
  usage ;  exit
elif [[ ! $remove_javadumps ]] ; then
 getSystemInfo
fi

getODMPodLogs

if [[ $remove_javadumps ]] ; then
 echo "Completed removing javadumps from all odm containers in namespace $ns"
else
 tar -cf ./MustGatherODM_K8S.$ns.$TIMESTAMP.tar -C  ${TEMP_FOLDER} .  &> $DEV_NULL
 echo "Completed collecting MustGather logs. Attach ./MustGatherODM_K8S.$ns.$TIMESTAMP.tar to support case."
fi

unset javadumps ; unset remove_javadumps
rm -rf ${TEMP_FOLDER}  &> $DEV_NULL
