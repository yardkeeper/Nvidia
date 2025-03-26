#!/bin/bash

REMOTE_HOST="192.168.55.1"
CURRENT_LOCATION=$(pwd)

echo -n "Enter username for remote user: "
read  REMOTE_USER
echo -n "Enter SSH password for $REMOTE_USER@$REMOTE_HOST: "
read -s REMOTE_PASSWORD 

check_packages_installed() {
    for PACKAGE in "$@"; do
        dpkg -l | grep -q "^ii  $PACKAGE"
        if [ $? -eq 0 ]; then
            echo "Package '$PACKAGE' is installed."
        else
            echo "Package '$PACKAGE' is not installed."
        fi
    done
}

rootfs(){
   tar -xzvpf $1.tar.gz
}

rootfs_cleanup(){

  if [ -f "$CURRENT_LOCATION/bootloader/system.img" ]; 
  then
    rm -f "$CURRENT_LOCATION/bootloader/system.img"
  fi

  
  if [ -d "$CURRENT_LOCATION/rootfs" ]; 
  then
    rm -rf "$CURRENT_LOCATION/rootfs"
  else
    sleep 1s
  fi
}

generate_random_id() {
  openssl rand -base64 7 | tr -dc 'A-Z0-9' | head -c 10
}

function create_default_user(){
 RAND_ID=$(generate_random_id)
 bash  tools/l4t_create_default_user.sh -u $REMOTE_USER -p $REMOTE_PASSWORD -n orin-$RAND_ID  --accept-license
}
   

function flash(){
    bash flash.sh  "$1" mmcblk0p1
    if [ $? -eq 1 ]; then
    echo "Exiting script."
    exit 1
fi

}

function flashnano(){
    bash tools/kernel_flash/l4t_initrd_flash.sh --external-device nvme0n1p1 -c tools/kernel_flash/flash_l4t_external.xml -p "-c bootloader/generic/cfg/flash_t234_qspi.xml" --network usb0 $1 external
    if [ $? -eq 1 ]; then
    echo "Exiting script."
    exit 1
fi

}

function ssh_check(){
while true; do
  ssh-keygen -f "/root/.ssh/known_hosts" -R "$REMOTE_HOST"
  sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $REMOTE_USER@$REMOTE_HOST exit

  if [ $? -eq 0 ]; 
  then
    echo "Connection successful!"
    break  
  else
    echo "Connection failed. Retrying..."
    sleep 2s
    
  fi
done
} 
export -f ssh_check


function ssh_copy() {
    echo "Copying files..."
    for dir in debs; 
    do
        sshpass -p "$REMOTE_PASSWORD" scp -o StrictHostKeyChecking=no -r "$CURRENT_LOCATION/$dir" "$REMOTE_USER@$REMOTE_HOST:/home/$REMOTE_USER"
    done
}


function ssh_install(){
sshpass -p "$REMOTE_PASSWORD" ssh -T $REMOTE_USER@$REMOTE_HOST << EOF
  echo "$REMOTE_PASSWORD" | sudo -S dpkg -i /home/$REMOTE_USER/debs/*
EOF
}


function install_orin(){
check_packages_installed "sshpass" "qemu-user-static"
rootfs_cleanup
rootfs "rootfs"
create_default_user
flash "jetson-agx-orin-devkit"
ssh_check
ssh_copy
ssh_install  
}

function install_orinnano(){
check_packages_installed "sshpass" "qemu-user-static"
rootfs_cleanup
rootfs "rootfs_nano"
create_default_user
flashnano "jetson-orin-nano-devkit-super"
ssh_check
ssh_copy
ssh_install


}

while true; do
    echo "Jetpack installion tool"
    echo ""
    echo "Installation options:"
    echo ""
    echo "1 - Install Jetpack 6.2 for Nvidia Orin "
    echo "2 - Install Jetpack 6.2 for Nvidia Orin Nano"
    read choice
    
    case "$choice" in
        1)
            
            install_orin
            break
        ;;
        
        2)
            
            install_orinnano
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
