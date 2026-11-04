#!/bin/sh
# Start one SSH agent per login.
#
# ~/.ssh/id_ed25519 has a passphrase, and no agent was running, so every git
# push over git@github.com: asked for it again - lazygit asks on each operation,
# which is where it hurts. This starts one agent per session and points
# Hyprland's environment at it, so terminals and everything spawned later
# inherit SSH_AUTH_SOCK.
#
# It deliberately does not call ssh-add: a modal passphrase prompt at login
# looks like a login screen and is easy to miss or mistype. The first ssh/git
# push in a terminal asks for the passphrase once and ssh loads the key into
# this agent, so the prompt appears where it can actually be answered.
#
# That last part needs `AddKeysToAgent yes` in ~/.ssh/config, which is not in
# this repo. With OpenSSH's default of no, ssh decrypts the key, signs, and
# drops it again: the agent stays empty and every push prompts.
#
# Started from hyprland/execs.lua. A config reload can run it again; a live
# socket makes that a no-op.
#
# Usage: ssh-agent.sh

set -u

SOCK="${XDG_RUNTIME_DIR:-$HOME/.ssh/agent}/ssh-agent.sock"

mkdir -p "$(dirname "$SOCK")" 2>/dev/null || exit 0

# Point ssh-add at our socket before probing it, otherwise it consults the
# default one, decides the agent is dead and starts a duplicate.
export SSH_AUTH_SOCK="$SOCK"

# Reuse a live agent. A socket can outlive its process (crash, kill), and
# ssh-add then exits 2 rather than 1 ("connected, but no identities").
if [ -S "$SOCK" ]; then
    ssh-add -l >/dev/null 2>&1
    [ $? -eq 2 ] && rm -f "$SOCK"
fi

if ! [ -S "$SOCK" ]; then
    eval "$(ssh-agent -a "$SOCK" -s)" >/dev/null 2>&1 || exit 0
fi

# Everything Hyprland spawns from now on (terminals, lazygit, git) sees this.
hyprctl setenv SSH_AUTH_SOCK "$SOCK" >/dev/null 2>&1 || true
systemctl --user set-environment SSH_AUTH_SOCK="$SOCK" >/dev/null 2>&1 || true

exit 0
