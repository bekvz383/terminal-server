#!/bin/sh
if [ "$(whoami)" = "tc" ] && [ "$(tty)" = "/dev/tty1" ] && [ -z "$DISPLAY" ]; then
    export HOME=/tmp/tc-home
    mkdir -p $HOME/.local/share/xorg $HOME/.config
    cat > $HOME/.xinitrc << 'XINITRC'
#!/bin/sh
xset -dpms
xset s off
xsetroot -solid '#1a1a2e'
exec /usr/local/bin/connect.sh
XINITRC
    chmod +x $HOME/.xinitrc
    exec startx -- :0 -nolisten tcp
fi
