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


function ssh_copy(){

   sshpass -p "$REMOTE_PASSWORD" scp -o StrictHostKeyChecking=no  -r $CURRENT_LOCATION/debs $REMOTE_USER@$REMOTE_HOST:/home/$REMOTE_USER
}

function install_orin(){
flash "jetson-agx-orin-devkit"
ssh_check
ssh_copy
sshpass -p "$REMOTE_PASSWORD" ssh $REMOTE_USER@$REMOTE_HOST 'sudo  -S dpkg -i /home/'$REMOTE_USER'/debs/*'
sshpass -p "$REMOTE_PASSWORD" ssh $REMOTE_USER@$REMOTE_HOST 'sudo  -S dpkg -i /home/'$REMOTE_USER'/deps/*' 
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