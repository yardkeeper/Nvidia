#!/bin/bash

REMOTE_HOST="192.168.1.2"
CURRENT_LOCATION=$(pwd)

REMOTE_USER_E="dXNlcg==" 
REMOTE_PASSWORD_E="QXV0bzEyMyE="


function check_ufw_status() {
    
    if systemctl is-active --quiet ufw.service;
     then
        echo ""
        echo "ufw service is active."
        echo "Please stop and disable ubuntu firewall using command: sudo systemctl stop ufw.service"
        exit 1
    else
        echo "ufw service is not active. Thats good."
    fi
}

function check_packages_installed() {
    for PACKAGE in "$@"; do
        dpkg -l | grep -q "^ii  $PACKAGE"
        if [ $? -eq 0 ]; then
            echo "Package '$PACKAGE' is installed."
        else
            echo "Package '$PACKAGE' is not installed."
            exit 1
        fi
    done
}

function rootfs(){
   tar -xzvpf $1.tar.gz
}

function rootfs_cleanup(){

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

function generate_random_id() {
  openssl rand -base64 32 | tr -dc 'A-Z0-9' | head -c 10
}

function create_default_user(){
 RAND_ID=$(generate_random_id)

  REMOTE_USER=$(echo "$REMOTE_USER_E" | base64 --decode)
  REMOTE_PASSWORD=$(echo "$REMOTE_PASSWORD_E" | base64 --decode)

 bash  tools/l4t_create_default_user.sh -u $REMOTE_USER -p $REMOTE_PASSWORD -n orin-$RAND_ID  --accept-license
}
   

function setup_static_ip() {
echo "Configuring static IP via NetworkManager and fixing eth0 via systemd link..."


  NM_DIR="$CURRENT_LOCATION/rootfs/etc/NetworkManager/system-connections"
  mkdir -p "$NM_DIR"

  NM_FILE="$NM_DIR/eth0-static.nmconnection"

  cat > "$NM_FILE" <<EOF
[connection]
id=eth0-static
type=ethernet
interface-name=eth0
autoconnect=true

[ethernet]
mac-address-blacklist=

[ipv4]
method=manual
addresses=${REMOTE_HOST}/24
EOF

  chmod 600 "$NM_FILE"

  echo "NetworkManager connection created: $NM_FILE"
  echo "Static IP set: 192.168.1.2/24"

# systemd .link
LINK_DIR="$CURRENT_LOCATION/rootfs/etc/systemd/network"
LINK_FILE="$LINK_DIR/10-jetson-onboard-ethernet.link"



cat > "$LINK_FILE" <<EOF
[Match]
Driver=r8168

[Link]
Name=eth0
EOF

chmod 644 "$LINK_FILE"

echo "systemd .link file created: $LINK_FILE"

}


function add_fstab_entry() {
FSTAB_FILE="$CURRENT_LOCATION/rootfs/etc/fstab"
  ENTRY="/dev/nvme0n1p1  /mnt  ext4  defaults 0 2"
  grep -qF "$ENTRY" "$FSTAB_FILE" || echo "$ENTRY" >> "$FSTAB_FILE"
  echo "Done"
}


function setup_jetson_clocks_service() {
SERVICE_DIR="$CURRENT_LOCATION/rootfs/etc/systemd/system"
SERVICE_FILE="$SERVICE_DIR/jetson_clocks.service"

  rm -f "$SERVICE_FILE"

  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Set Jetson clocks to max performance
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/jetson_clocks
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

  chmod 644 "$SERVICE_FILE"

  echo "Service created: $SERVICE_FILE"

  WANTS_DIR="$CURRENT_LOCATION/rootfs/etc/systemd/system/multi-user.target.wants"
  mkdir -p "$WANTS_DIR"

  ln -sf ../jetson_clocks.service "$WANTS_DIR/jetson_clocks.service"
}



function flash(){
bash flash.sh  "$1" mmcblk0p1
if [ $? -eq 1 ]; 
  then
    echo "Error: Please verify if the Jetson AGX Orin is connected via USB cable and in recovery mode. " >&2
    exit 1
fi

}

function flashnano(){
    bash tools/kernel_flash/l4t_initrd_flash.sh --external-device nvme0n1p1 -c tools/kernel_flash/flash_l4t_external.xml -p "-c bootloader/generic/cfg/flash_t234_qspi.xml" --network usb0 $1 external
    if [ $? -eq 1 ];
     then
      echo "Error: Please verify if the Jetson Orin Nano is connected via USB cable and in recovery mode. " >&2
      exit 1
fi

}


function wait_for_device() {
    echo "Waiting for Jetson in recovery mode..."
    while true; do
        lsusb | grep -q "0955:" && break
        sleep 2
    done
}

function detect_jetson() {

    line=$(lsusb | grep "0955:")

    if [ -z "$line" ]; then
        echo "No NVIDIA device found"
        return 1
    fi

    echo "Detected device:"
    echo "$line"
    echo

    pid=$(echo "$line" | awk -F: '{print $3}' | awk '{print $1}')

    if [ "$pid" = "7523" ]; then
        echo "Model: Orin Nano"
        DEVICE="nano"
    elif [ "$pid" = "7323" ]; then
        echo "Model: Orin NX"
        DEVICE="nx"
    elif [ "$pid" = "7023" ]; then
        echo "Model: AGX Orin"
        DEVICE="agx"
    else
        echo "Unknown PID: $pid"
        return 1
    fi

    return 0
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
  echo "$REMOTE_PASSWORD" | sudo -S ldconfig
  echo "/mnt/  192.168.1.0/24(fsid=1001,rw,sync,no_subtree_check)" | sudo tee -a /etc/exports > /dev/null

EOF
}


check_ufw_status

function install_orinagx(){
check_packages_installed "sshpass" "qemu-user-static" "libxml2-utils"
rootfs_cleanup
rootfs "rootfs"
create_default_user
setup_static_ip
setup_jetson_clocks_service
add_fstab_entry
flash "jetson-agx-orin-devkit"
ssh_check
ssh_copy
ssh_install  
}

function install_orinnano(){
check_packages_installed "sshpass" "qemu-user-static" "libxml2-utils"
rootfs_cleanup
rootfs "rootfs_nano"
create_default_user
setup_static_ip
setup_jetson_clocks_service
flashnano "jetson-orin-nano-devkit-super"
ssh_check
ssh_copy
ssh_install


}

wait_for_device

detect_jetson
if [ $? -ne 0 ]; then
    echo "Detection failed"
    exit 1
fi

if [ "$DEVICE" = "agx" ]; then
    install_orinagx
elif [ "$DEVICE" = "nano" ]; then
    install_orinnano

else
    echo "Unsupported device"
    exit 1
fi

