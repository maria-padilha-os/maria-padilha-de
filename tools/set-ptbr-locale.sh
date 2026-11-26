#!/bin/sh
# Switch the Maria Padilha system locale to Brazilian Portuguese.
# Run as root: sudo tools/set-ptbr-locale.sh
set -eu

[ "$(id -u)" -eq 0 ] || {
    echo "set-ptbr-locale: run this as root (sudo $0)" >&2
    exit 1
}

stamp=$(date +%Y%m%d-%H%M%S)
[ -f /etc/locale.conf ] && cp -a /etc/locale.conf "/etc/locale.conf.bak-$stamp"

if grep -q '^#pt_BR.UTF-8 UTF-8' /etc/locale.gen; then
    sed -i 's/^#pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen
fi
locale-gen

cat > /etc/locale.conf <<'EOF'
LANG=pt_BR.UTF-8
LANGUAGE=pt_BR:pt
LC_CTYPE=pt_BR.UTF-8
LC_NUMERIC=pt_BR.UTF-8
LC_TIME=pt_BR.UTF-8
LC_COLLATE=pt_BR.UTF-8
LC_MONETARY=pt_BR.UTF-8
LC_MESSAGES=pt_BR.UTF-8
LC_PAPER=pt_BR.UTF-8
LC_NAME=pt_BR.UTF-8
LC_ADDRESS=pt_BR.UTF-8
LC_TELEPHONE=pt_BR.UTF-8
LC_MEASUREMENT=pt_BR.UTF-8
LC_IDENTIFICATION=pt_BR.UTF-8
EOF

echo "set-ptbr-locale: system locale written (backup: /etc/locale.conf.bak-$stamp)"
echo "set-ptbr-locale: log out and back in (or reboot) to update the session, greeter and services"
localectl status
