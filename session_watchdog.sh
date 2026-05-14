#!/bin/bash
IDLE_TIMEOUT=300
CHECK_INTERVAL=60
LOG_FILE="/var/log/broker/watchdog.log"

mkdir -p "$(dirname $LOG_FILE)"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "Watchdog started"

while true; do
    sleep $CHECK_INTERVAL
    
    RUNNING_VMS=$(virsh list --state-running --name 2>/dev/null | grep '^win10-user')
    
    for VM in $RUNNING_VMS; do
        MAC=$(virsh domiflist "$VM" 2>/dev/null | awk 'NR==3{print $5}')
        [ -z "$MAC" ] && continue
        
        # IP олох
        VM_IP=""
        [ -f /var/lib/misc/dnsmasq.leases ] && \
            VM_IP=$(awk -v mac="${MAC,,}" 'tolower($2)==mac{print $3;exit}' /var/lib/misc/dnsmasq.leases)
        
        [ -z "$VM_IP" ] && \
            VM_IP=$(arp -n | awk -v mac="${MAC,,}" 'tolower($3)==mac{print $1;exit}')
        
        [ -z "$VM_IP" ] && { log "WARN: $VM IP not found"; continue; }
        
        # RDP холболт шалгах
        RDP_CONN=$(ss -tn 2>/dev/null | awk -v ip="$VM_IP:3389" '$1=="ESTAB" && $4==ip{n++} END{print n+0}')
        
        IDLE_FILE="/tmp/watchdog_idle_${VM}"
        
        if [ "$RDP_CONN" -gt 0 ]; then
            [ -f "$IDLE_FILE" ] && rm -f "$IDLE_FILE" && log "$VM: RDP active, idle cleared"
        else
            if [ ! -f "$IDLE_FILE" ]; then
                touch "$IDLE_FILE"
                log "$VM ($VM_IP): no RDP, idle timer started"
            else
                IDLE_TIME=$(( $(date +%s) - $(stat -c %Y "$IDLE_FILE") ))
                if [ "$IDLE_TIME" -ge "$IDLE_TIMEOUT" ]; then
                    virsh suspend "$VM" >/dev/null 2>&1 && \
                        log "$VM: suspended (idle ${IDLE_TIME}s)" && \
                        rm -f "$IDLE_FILE"
                fi
            fi
        fi
    done
done
