#!/bin/bash
LOG_FILE="/var/log/broker/monitor.log"
ALERT_LOG="/var/log/broker/alerts.log"
DISK_THRESHOLD=80
RAM_THRESHOLD=90

mkdir -p "$(dirname $LOG_FILE)"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }
alert() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ALERT: $1" >> "$ALERT_LOG"; }

# CPU load
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1)

# RAM хэрэглээ
RAM_TOTAL=$(free -m | awk 'NR==2{print $2}')
RAM_USED=$(free -m | awk 'NR==2{print $3}')
RAM_PCT=$(( RAM_USED * 100 / RAM_TOTAL ))

# Disk хэрэглээ
DISK_PCT=$(df / | awk 'NR==2{print $5}' | tr -d '%')

# KSM хэмнэлт
KSM_PAGES=$(cat /sys/kernel/mm/ksm/pages_shared 2>/dev/null || echo 0)
KSM_MB=$(( KSM_PAGES * 4 / 1024 ))

# Ажиллаж буй VM тоо
VM_COUNT=$(virsh list --state-running --name 2>/dev/null | grep -c 'win10-user')

log "CPU:${CPU}% RAM:${RAM_USED}/${RAM_TOTAL}MB(${RAM_PCT}%) DISK:${DISK_PCT}% VMs:${VM_COUNT} KSM:${KSM_MB}MB"

# Alert шалгах
[ "$DISK_PCT" -ge "$DISK_THRESHOLD" ] && alert "Disk ${DISK_PCT}% — /var/lib/libvirt/images цэвэрлэх шаардлагатай"
[ "$RAM_PCT"  -ge "$RAM_THRESHOLD"  ] && alert "RAM ${RAM_PCT}% — VM suspend шаардлагатай"
