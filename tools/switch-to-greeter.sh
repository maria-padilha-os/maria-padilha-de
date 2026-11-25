#!/bin/sh
# Switch this machine from LightDM to greetd + the Maria Padilha greeter.
#
#   sudo tools/switch-to-greeter.sh
#   sudo tools/switch-to-greeter.sh --rollback
#
# The install mode does not stop the running display manager: it prepares the
# next boot. Reboot after it succeeds. The rollback mode is deliberately
# available from a TTY and does not need the greeter to work.
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd) || exit 1

if [ "$(id -u)" -ne 0 ]; then
    echo "run this with sudo" >&2
    exit 1
fi

if [ "${1:-}" = "--rollback" ]; then
    systemctl disable greetd.service 2>/dev/null || true
    systemctl enable lightdm.service
    ln -sfn /usr/lib/systemd/system/lightdm.service /etc/systemd/system/display-manager.service
    echo "LightDM restored. Reboot to use it."
    exit 0
fi

if [ ! -x "$root/bin/padilha-greeter" ] || [ ! -x "$root/bin/padilha-greeter-qs" ]; then
    echo "greeter binaries not found under $root/bin" >&2
    exit 1
fi

pacman -S --needed --noconfirm greetd greetd-tuigreet cage

install -Dm755 "$root/bin/padilha-greeter" /usr/local/bin/padilha-greeter
install -Dm755 "$root/bin/padilha-greeter-qs" /usr/local/bin/padilha-greeter-qs
rm -rf /usr/local/share/greeter
cp -a "$root/share/greeter" /usr/local/share/greeter
chmod -R a+rX /usr/local/share/greeter

install -d -m 755 /etc/greetd
if [ -f /etc/greetd/config.toml ]; then
    cp -a /etc/greetd/config.toml "/etc/greetd/config.toml.bak.$(date +%Y%m%d-%H%M%S)"
fi

cat >/etc/greetd/config.toml <<'EOF'
[terminal]
vt = 1

[default_session]
command = "/usr/local/bin/padilha-greeter-qs"
user = "greeter"
EOF
chmod 644 /etc/greetd/config.toml

if ! id greeter >/dev/null 2>&1; then
    useradd --system --user-group --home-dir /var/lib/greetd \
        --shell /usr/bin/nologin greeter
fi
install -d -m 755 -o greeter -g greeter /var/lib/greetd

systemctl disable lightdm.service 2>/dev/null || true
systemctl enable greetd.service
ln -sfn /usr/lib/systemd/system/greetd.service /etc/systemd/system/display-manager.service

echo
echo "Prepared for the next boot:"
echo "  - greetd enabled, LightDM disabled (still running until reboot)"
echo "  - Quickshell greeter: /usr/local/bin/padilha-greeter-qs"
echo "  - tuigreet fallback: /usr/bin/tuigreet"
echo
echo "Reboot to test. If the login fails, switch to a TTY and run:"
echo "  sudo $root/tools/switch-to-greeter.sh --rollback"
echo "  sudo reboot"
