#!/bin/bash
echo "Welcome to I.R.N.C.O.L.T - Intalling and removing nvidia cuda and other libraries tool"
CURRENT_DIR=$(pwd)

NVIDIA_REPO_URL="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/"
NEXUS_REPO_URL="https://nexus.compdomain.com/repository/nvidia2204"
TRT_VERSION="8.6.1.6-1+cuda12.0"
DEBS="$CURRENT_DIR/debs"


function add_apt_key() {
  key=$1
  apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv $key
}
export -f add_apt_key

function remove(){
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


function repo(){
 
  ping -c1 192.113.13.25 > /dev/null
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

function exit_f(){
exit 0 
}
export -f exit_f


function install_local_packages() {
    dir=$1
    
    if [[ ! -d "$dir" ]]; then
        echo "Error: Folder '$dir' does not exist."
        exit 1
    else
        
        sudo dpkg -i --force-all  $dir/*.deb
    fi
    
}

function install_nvidia_tools(){

repo 

apt update && apt install cuda-12-0 cuda-12-2 cuda-toolkit-12-2 libcudnn8=8.9.4.25-1+cuda12.2 libcudnn8-dev=8.9.4.25-1+cuda12.2
install_local_packages "$DEBS"
cp /var/nv-tensorrt-local-repo-ubuntu2204-8.6.1-cuda-12.0/nv-tensorrt-local-42B2FC56-keyring.gpg /usr/share/keyrings/ &&\
sudo cp /var/nv-tensorrt-local-repo-ubuntu2204-8.6.1-cuda-12.0/nv-tensorrt-local-42B2FC56-keyring.gpg /usr/share/keyrings/ && rm /etc/apt/sources.list.d/cuda-ubuntu2204-x86_64.list && apt clean && apt update 
apt install sudo apt install tensorrt=$TRT_VERSION tensorrt-dev=$TRT_VERSION libnvinfer-dev=$TRT_VERSION libnvinfer-plugin-dev=$TRT_VERSION libnvinfer-headers-dev=$TRT_VERSION  libnvinfer-headers-plugin-dev=$TRT_VERSION libnvinfer-lean-dev=$TRT_VERSION libnvinfer-dispatch-dev=$TRT_VERSION libnvinfer-vc-plugin-dev=$TRT_VERSION libnvonnxparsers-dev=$TRT_VERSION libnvinfer-bin=$TRT_VERSION libnvinfer-samples=$TRT_VERSION -y
}




while true; do
    echo "Installation options:"
    echo ""
    echo "1 - nVidia tools for Ubuntu 22.04 LTS"
    echo "r - Remove all installed packages"
    echo "e - Exit from installation script"
    read choice
    
    case "$choice" in
        1)
            
            install_nvidia_tools
            break
        ;;
     
         r)
             remove
        
        ;;
        e)
             exit_f
        
        ;;
         *)
            echo "Invalid input."
        ;;
    esac
done
