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
   tar -xzvpf rootfs.tar.gz
}

rootfs_cleanup(){
  if [ -d "$CURRENT_LOCATION/rootfs" ];
  then
    rm -rf $CURRENT_LOCATION/rootfs
  else
    sleep 1s
  fi
}

generate_random_id() {
  openssl rand -base64 7 | tr -dc 'A-Za-z0-9' | head -c 10
}

function create_default_user(){
 RAND_ID=$(generate_random_id)
 bash  tools/l4t_create_default_user.sh -u $REMOTE_USER -p $REMOTE_PASSWORD -n orin-$RAND_ID  --accept-license
}
   

function flash(){
    bash flash.sh "$1" mmcblk0p1
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

function install_orin(){
check_packages_installed "sshpass" "qemu-user-static"
rootfs_cleanup
rootfs
create_default_user
flash "jetson-agx-orin-devkit"
ssh_check
ssh_copy

#SRC_DIR="./aksusbd-9.13.1"

sshpass -p "$REMOTE_PASSWORD" ssh -T $REMOTE_USER@$REMOTE_HOST << EOF
 echo "$REMOTE_PASSWORD" | sudo -S dpkg -i /home/$REMOTE_USER/debs/*
 #echo "$REMOTE_PASSWORD" | sudo -S tar -xzf /home/$REMOTE_USER/deps/OpenCV-4.5.0-aarch64-Orin-JetPack-5.1.2.tar.gz --strip-components=1 -C /usr/local/
 # echo "$REMOTE_PASSWORD" | sudo -S tar -xzvf /home/$REMOTE_USER/deps/aksusbd_33876-9.13.1_arm64_and_amd64.tar.gz
 # echo "$REMOTE_PASSWORD" | sudo -S ./aksusbd-9.13.1/dinst "$SRC_DIR"
  
EOF

 
  
}


while true; do
    echo "Jetpack installion tool"
    echo ""
    echo "Installation options:"
    echo ""
    echo "1 - Install Jetpack 5.1.2 for Nvidia Orin "
    
    read choice
    
    case "$choice" in
        1)
            
            install_orin
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
