#!/bin/bash

REMOTE_HOST="192.168.55.1"
CURRENT_LOCATION=$(pwd)

echo -n "Enter username for remote user: "
read  REMOTE_USER
echo -n "Enter SSH password for $REMOTE_USER@$REMOTE_HOST: "
read -s REMOTE_PASSWORD 

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
    for dir in debs deps; 
    do
        sshpass -p "$REMOTE_PASSWORD" scp -o StrictHostKeyChecking=no -r "$CURRENT_LOCATION/$dir" "$REMOTE_USER@$REMOTE_HOST:/home/$REMOTE_USER"
    done
}

function install_orin(){
flash "jetson-agx-orin-devkit"
ssh_check
ssh_copy

sshpass -p "$REMOTE_PASSWORD" ssh -T $REMOTE_USER@$REMOTE_HOST << EOF
  echo "$REMOTE_PASSWORD" | sudo -S dpkg -i /home/$REMOTE_USER/debs/*
  echo "$REMOTE_PASSWORD" | sudo -S tar -xzf /home/$REMOTE_USER/deps/OpenCV-4.5.0-aarch64-Orin-JetPack-5.1.2.tar.gz --strip-components=1 -C /usr/local/
  echo "$REMOTE_PASSWORD" | sudo -S ldconfig
  echo "$REMOTE_PASSWORD" | sudo -S mkdir -p /mnt/videos
  echo "$REMOTE_PASSWORD" | sudo -S chown -R nobody:nogroup /mnt/videos/
  echo "$REMOTE_PASSWORD" | sudo -S chmod 777 /mnt/videos/
  echo "/mnt/  192.168.1.0/24(fsid=1001,rw,sync,no_subtree_check)" | sudo tee -a /etc/exports > /dev/null
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
