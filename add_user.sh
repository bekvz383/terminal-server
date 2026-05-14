#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

USERNAME=$1
VM_NAME="win10-$USERNAME"
VM_DISK="/var/lib/libvirt/images/${VM_NAME}.qcow2"
BASE_DISK="/var/lib/libvirt/images/win10-base.qcow2"

useradd -m -s /bin/false $USERNAME
echo "$USERNAME:password123" | chpasswd

qemu-img create -f qcow2 -b $BASE_DISK -F qcow2 $VM_DISK
chown libvirt-qemu:kvm $VM_DISK

virt-install \
  --name $VM_NAME \
  --memory 3072 \
  --vcpus 2,sockets=1,cores=2,threads=1 \
  --cpu host-passthrough,cache.mode=passthrough \
  --disk path=$VM_DISK,format=qcow2,bus=virtio,cache=writeback,io=threads,discard=unmap \
  --os-variant win10 \
  --network bridge=br0,model=virtio \
  --graphics none \
  --noautoconsole \
  --import

sleep 15
virsh suspend $VM_NAME

sqlite3 /var/lib/broker/users.db \
  "INSERT OR REPLACE INTO users (username, vm_name, vm_disk) VALUES ('$USERNAME', '$VM_NAME', '$VM_DISK');"
