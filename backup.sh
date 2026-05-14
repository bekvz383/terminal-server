#!/bin/bash
LOG_FILE="/var/log/broker/backup.log"
BACKUP_DIR="/var/lib/libvirt/images/backups"

mkdir -p "$BACKUP_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }

log "Backup started"

# Ажиллаж буй VM-уудын snapshot авах
for VM in $(virsh list --state-running --name 2>/dev/null | grep 'win10-user'); do
    SNAP="backup_$(date +%Y%m%d_%H%M)"
    virsh snapshot-create-as "$VM" "$SNAP" \
        --description "Auto backup" \
        --atomic >/dev/null 2>&1 && \
        log "$VM: snapshot $SNAP OK" || \
        log "ERROR: $VM snapshot failed"
done

# Overlay disk-уудыг copy хийх
for DISK in /var/lib/libvirt/images/win10-user*.qcow2; do
    NAME=$(basename "$DISK")
    cp "$DISK" "$BACKUP_DIR/${NAME}.bak" && \
        log "$NAME backup OK" || \
        log "ERROR: $NAME backup failed"
done

log "Backup finished"
