#!/bin/bash
echo "Welcome to I.R.N.C.O.L.T - Intalling and removing nvidia cuda and other libraries tool"

NVIDIA_REPO_URL="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/"
NEXUS_REPO_URL="https://nexus.foresightauto.com/repository/nvidia2204"

add_apt_key() {
  key=$1
  apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv $key
}
export -f 

remove(){
  apt remove nvidia-* libnvidia-* cuda-* libcudnn8 -y
  packages=$(dpkg -l | egrep 'libnv|nvidia|cuda|cud' | cut -d " " -f3)

  for pkg in $packages
   do
     #echo $pkg
     dpkg -P --force-all  $pkg

  done
  apt autoremove -y
  rm -rf /usr/local/cuda*
}
export -f remove


repo(){
 
  ping -c1 192.133.13.225 > /dev/null
  if [[ $? -eq 0 ]]; then
  
    echo "Nexus server reachable, installing from Nexus Repository"
    sudo cp sources.list.nexus.2204 /etc/apt/sources.list
    sudo cp ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
    sudo apt-key add public.gpg.key
    sudo apt-key add docker.gpg
    sudo apt-key add gpg.BDD3FD95B65ECA48.key
    add_apt_key A4B469963BF863CC
    wget $REPO_URL/cuda-keyring_1.1-1_all.deb && sudo dpkg -i cuda-keyring_1.1-1_all.deb && sudo apt update
    echo "deb $NEXUS_REPO_URL /" | sudo tee -a /etc/apt/sources.list


  elif [[ $? -eq 1 ]]; then
    ping -c1 developer.download.nvidia.com > /dev/null
    if [[ $? -eq 0 ]]; then
    
      echo "Nvidia server reachable, installing from Nvidia Repository"
      sudo cp sources.list.local /etc/apt/sources.list
      wget $REPO_URL/cuda-keyring_1.1-1_all.deb && sudo dpkg -i cuda-keyring_1.1-1_all.deb && sudo apt update
      echo "deb $NVIDIA_REPO_URL /" | sudo tee -a /etc/apt/sources.list
    else

      echo "Both Nexus and Nvidia repositories are unavailable."
      exit 0
    fi
  fi
}
export -f repo



install_nvidia_setup(){

repo 

apt update && apt install cuda-12-0 cuda-12-2 cuda-toolkit-12-2 libcudnn8=8.9.4.25-1+cuda12.2 libcudnn8-dev=8.9.4.25-1+cuda12.2


}




while true; do
    echo "Installation options:"
    echo ""
    echo "1 - nVidia tools for Ubuntu 22.04 LTS"
    
    echo "r - Remove all installed packages"
    read choice
    
    case "$choice" in
        1)
            
            install_nvidia_setup
            
        ;;
     
         r)
             remove
        
        ;;
         *)
            echo "Invalid input."
        ;;
    esac
done
