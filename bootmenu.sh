#!/bin/bash 
#
#   bootmenu.sh
#
#------------
#
function install_odm8110_K8S() {
    echo ""
     if [[  $(helm ls -A -q | grep 8110) ]] ; then
       echo "ODM 8.11.0.1 Helm Chart already installed"
    else 
      export odm_ns="odm8110" ; echo $odm_ns > ~/.odm_ns ; installODMHelmChart.sh
    fi
     export odm_ns="odm8110" ; echo $odm_ns > ~/.odm_ns
    menu
    echo ""
}

function install_odm81051_K8S() {
    echo ""
     if [[  $(helm ls -A -q | grep 8105) ]] ; then
       echo "ODM 8.10.5.1 Helm Chart already installed"
    else  
     export odm_ns="odm8105" ; echo $odm_ns > ~/.odm_ns ; installODMHelmChart.sh
    fi
     export odm_ns="odm8105" ; echo $odm_ns > ~/.odm_ns
     menu 
    echo ""
}

function install_odm811_CP4BA2103() {
    echo ""
     echo "Option comming soon "
     # export odm_ns="odm8110" ; echo $odm_ns > ~/.odm_ns
    echo ""
}

function install_odm8105_CP4BA2201() {
    echo ""
    echo "Option comming soon "
    # export odm_ns="odm8110" ; echo $odm_ns > ~/.odm_ns
    menu
    echo ""
}


function uninstall_odm8110_K8S() {
    echo ""
   if [[  $(helm ls -A -q | grep 8110) ]] ; then
    export odm_ns="odm8110" ; echo $odm_ns > ~/.odm_ns ; uninstallODMHelmChart.sh
   else
    echo "ODM 8.11.0.1 Helm Chart not installed"
   fi
   menu
    echo ""
}

function reinstall_odm8110_K8S() {
    export odm_ns="odm8110" ; echo $odm_ns > ~/.odm_ns ; uninstallODMHelmChart.sh
     sleep 30s
    install_odm8110_K8S
}

function uninstall_odm81051_K8S() {
    echo ""
    if [[  $(helm ls -A -q | grep 8105) ]] ; then
     export odm_ns="odm8105" ; echo $odm_ns > ~/.odm_ns ; uninstallODMHelmChart.sh
   else
    echo "ODM 8.10.5.1 Helm Chart not installed"
   fi
    menu
    echo ""
}

function reinstall_odm81051_K8S() {
   export odm_ns="odm8105" ; echo $odm_ns > ~/.odm_ns ; uninstallODMHelmChart.sh
    sleep 30s
    install_odm81051_K8S
}

function displayInfo() {
    echo ""
    login_kube.sh ;  displayInfo.sh
    menu
    echo ""
}

function displayWASInfo() {
    echo ""
    displayWASInfo.sh 
    menu
    echo ""
}

function display_k9s_K8S() {
    echo ""
    ns=$(oc project -q)
    login_kube.sh ; startK9s.sh  $ns
    echo ""
}

function OCP_clusterOnly() {
   export odm_ns="" ; echo $odm_ns > ~/.odm_ns
   bootstrap_crc.sh
  menu
}

function start_odm8110_WAS9() {
    echo ""
  #  if [[ $(grep  STARTED /tmp/.odm8110WASstatus)  ]] ; then
      sudo /opt/IBM/WAS9/AppServer/profiles/ODM8110sa/bin/startServer.sh  server1
      displayWASInfo.sh
  # else
  #    echo "ODM 8.11 WAS9 profile already started"
  # fi
    menu
    echo ""
}

function stop_odm8110_WAS9() {
    echo ""
    sudo /opt/IBM/WAS9/AppServer/profiles/ODM8110sa/bin/stopServer.sh  server1 -username admin -password admin
    displayWASInfo.sh
    menu
    echo ""
}

# Color  Variables
green='\e[32m'
blue='\e[34m'
red='\e[31m'
clear='\e[0m'

# Color Functions
ColorGreen(){
        echo -ne $green$1$clear
}
ColorBlue(){
        echo -ne $blue$1$clear
}
ColorRed(){
        echo -ne $red$1$clear
}


menu(){
. /etc/environment 
echo -ne "
Menu Options:
$(ColorGreen '1)') Install Helm Chart: ODM 8.11.0.1/DB2 on K8S/OpenShift $ocpVersion
$(ColorGreen '2)') Install Helm Chart: ODM 8.10.5.1/DB2 on K8S/OpenShift $ocpVersion
$(ColorGreen '3)') Install ODM 8.11.0.1 / DB2 on CP4BA 22.0.1 OpenShift $ocpVersion (coming soon)
$(ColorGreen '4)') Install ODM 8.10.5.1 / DB2 on CP4BA 21.0.3 OpenShift $ocpVersion (coming soon)
$(ColorGreen '5)') Uninstall Helm Chart: ODM 8.11.0.1/DB2 on K8S/OpenShift $ocpVersion
$(ColorGreen '6)') Uninstall Helm Chart: ODM 8.10.5.1/DB2 on K8S/OpenShift $ocpVersion
$(ColorGreen '7)') Display Helm chart status/info/URLs 
$(ColorGreen '8)') Open K9S Kubernetes Dashboard 
$(ColorGreen '9)') Access OpenShift Web Console (in vnc session)
$(ColorGreen 'A)') Start VNC session 
$(ColorGreen 'B)') Start ODM 8.11.0 / DB2 WAS9 stand-alone profile 
$(ColorGreen 'C)') Stop  ODM 8.11.0 / DB2 WAS9 stand-alone profile 
$(ColorGreen 'D)') Display ODM/WAS9 status/URLs
$(ColorGreen '0)') Exit to shell, run 'menu' to return
$(ColorBlue 'Choose an option:') "
        read a
        case $a in
                1) install_odm8110_K8S; menu ;;
                2) install_odm81051_K8S; menu ;;
                3) install_odm811_CP4BA2201; menu ;;
                4) install_odm8105_CP4BA2103; menu ;;
                5) uninstall_odm8110_K8S; menu ;;
                6) uninstall_odm81051_K8S; menu ;;
                7) displayInfo; menu ;;
                8) display_k9s_K8S ; menu ;;
                9) crc console ; menu ;;
                A) startvnc.sh ; menu ;;
                B) start_odm8110_WAS9; menu ;;
                C) stop_odm8110_WAS9; menu ;;
                D) displayWASInfo; menu ;;
                0) echo "run cmd: 'menu' to return "  ; exit 0   ;;
                *) echo -e $red"Wrong option."$clear ;
                   echo "choose from: 0-9, A-D" ; menu ;;
        esac
}

echo "Starting menu ..."
login_kube.sh
menu
