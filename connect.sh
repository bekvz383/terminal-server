#!/bin/sh
export DISPLAY=:0
export HOME=/tmp/tc-home

BROKER_HOST="192.168.10.100"
BROKER_PORT="2222"

while true; do
    CREDS=$(zenity --password --username \
        --title="Лабораторийн систем" \
        --text="Нэвтрэх нэр болон нууц үгээ оруулна уу" \
        --width=400 2>/dev/null)

    if [ -z "$CREDS" ]; then
        zenity --question \
            --title="Системээс гарах" \
            --text="Компьютерийг унтраахыг хүсэж байна уу?" \
            --width=300 2>/dev/null
        [ $? -eq 0 ] && sudo poweroff
        continue
    fi

    USER=$(echo "$CREDS" | cut -d'|' -f1)
    PASS=$(echo "$CREDS" | cut -d'|' -f2)
    [ -z "$USER" ] || [ -z "$PASS" ] && continue

    zenity --info \
        --text="Холбогдож байна...\nТүр хүлээнэ үү." \
        --width=300 --timeout=60 2>/dev/null &
    ZENITY_PID=$!

    RESULT=$(echo "AUTH $USER $PASS" | \
        nc -w 60 ${BROKER_HOST} ${BROKER_PORT} 2>/dev/null)

    kill $ZENITY_PID 2>/dev/null

    if echo "$RESULT" | grep -q "^OK"; then
        VMIP=$(echo "$RESULT" | awk '{print $2}' | cut -d: -f2)
        xfreerdp /v:$VMIP \
            /u:Dell /p:password123 \
            /f /cert-ignore /sec:rdp \
            +clipboard /dynamic-resolution \
            2>/dev/null
    else
        zenity --error \
            --text="Нэвтрэлт амжилтгүй.\nХэрэглэгчийн нэр эсвэл нууц үг буруу байна." \
            --width=300 2>/dev/null
    fi
done
