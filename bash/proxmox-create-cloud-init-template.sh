#!/usr/bin/env bash

# Set VM ID and name
VMID=9003
VMNAME="ubuntu-server-24.04-20250701"
MEMORY=2048
CORES=2
BRIDGE="vmbr0"
IMAGE="noble-server-cloudimg-amd64.img"
STORAGE="Local-Proxmox"

wget "https://cloud-images.ubuntu.com/noble/current/$IMAGE"

echo "Creating VM ${VMID} (${VMNAME})..."
qm create "$VMID" --memory "$MEMORY" --core "$CORES" --name "$VMNAME" --net0 virtio,bridge="$BRIDGE"

echo "Importing disk image..."
qm importdisk "$VMID" "$IMAGE" "$STORAGE"

echo "Attaching disk to VM..."
qm set "$VMID" --scsihw virtio-scsi-pci --scsi0 "${STORAGE}:vm-${VMID}-disk-0"

echo "Adding cloud-init drive..."
qm set "$VMID" --ide2 "${STORAGE}:cloudinit"

echo "Setting boot options..."
qm set "$VMID" --boot c --bootdisk scsi0

echo "Adding serial console..."
qm set "$VMID" --serial0 socket --vga serial0

echo "Resizing disk..."
qm resize "$VMID" scsi0 +10G

echo "Converting VM to template..."
qm template "$VMID"

echo "Done. You can now clone template ${VMID} as needed."

