#!/bin/sh
# Padilha session restore, deliberately small.
#
#   restore.sh snapshot             save one allowlisted class per window
#   restore.sh restore [--dry-run]  reopen the last snapshot once per Hyprland run
#   restore.sh show                 print the saved snapshot
#   restore.sh watch                snapshot every INTERVAL seconds
#
# State is JSON under $XDG_STATE_HOME/padilha. A snapshot records only window
# classes and numeric workspace ids; the command is looked up in the fixed table
# below. Editing the snapshot cannot introduce a new command. No sudo, no root.
set -u
umask 077

STATE_HOME=${XDG_STATE_HOME:-"$HOME/.local/state"}
STATE_DIR=$STATE_HOME/padilha
SNAP=${PADILHA_RESTORE_FILE:-"$STATE_DIR/session-restore.json"}
MAX=${PADILHA_RESTORE_MAX:-8}
WAIT=${PADILHA_RESTORE_WAIT:-10}
INTERVAL=${PADILHA_RESTORE_INTERVAL:-60}
DRY_RUN=0
tmpdir=

case "$SNAP" in
    */*) snap_dir=${SNAP%/*} ;;
    *) snap_dir=. ;;
esac

cleanup() {
    if [ -n "$tmpdir" ]; then
        rm -rf "$tmpdir"
    fi
}
trap cleanup 0
trap 'exit 1' 1 2 15

usage() {
    printf '%s\n' \
        "usage: restore.sh snapshot" \
        "       restore.sh restore [--dry-run]" \
        "       restore.sh show" \
        "       restore.sh watch" >&2
    exit 2
}

die() {
    printf 'restore.sh: %s\n' "$*" >&2
    exit 1
}

say() {
    printf '%s\n' "$*"
}

require_tools() {
    for tool in "$@"; do
        command -v "$tool" >/dev/null 2>&1 || die "missing $tool"
    done
}

# Only these classes are restored. The command is fixed here, not read from the
# snapshot or from /proc. Extend this table and the README together.
command_for_class() {
    app_key=$(printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]')
    case "$app_key" in
        org.wezfurlong.wezterm) printf '%s\n' wezterm ;;
        firefox) printf '%s\n' firefox ;;
        thunar) printf '%s\n' thunar ;;
        foot) printf '%s\n' foot ;;
        spotify) printf '%s\n' spotify ;;
        *) return 1 ;;
    esac
}

cmd_snapshot() {
    require_tools hyprctl jq
    mkdir -p "$STATE_DIR" "$snap_dir" || die "cannot create $STATE_DIR"
    tmpdir=$(mktemp -d "$STATE_DIR/.snapshot.XXXXXX") || die "cannot create a temporary directory"

    hyprctl clients -j > "$tmpdir/clients.json" 2>/dev/null || die "cannot read Hyprland clients"

    # Newest focus first, one row per window. Special workspaces are negative or
    # named special:*; they are session stubs and are intentionally skipped.
    jq -r '
        [ .[]
          | select(.mapped == true and .hidden == false)
          | select((.workspace.id // 0) > 0)
          | select(((.workspace.name // "") | startswith("special:")) | not)
          | {class: (.class // .initialClass // ""),
             workspace: (.workspace.id // 0),
             focus: (.focusHistoryID // 999999)}
        ]
        | sort_by(.focus)
        | .[]
        | select(.class != "")
        | [.class, (.workspace | tostring)]
        | @tsv
    ' "$tmpdir/clients.json" > "$tmpdir/classes.tsv" || die "cannot parse Hyprland clients"

    : > "$tmpdir/apps.ndjson"
    count=0
    seen=' '
    tab=$(printf '\t')
    while IFS="$tab" read -r class workspace; do
        [ "$count" -lt "$MAX" ] || break
        [ -n "$class" ] || continue
        app=$(command_for_class "$class") || continue
        case "$workspace" in
            ''|*[!0-9]*) continue ;;
        esac
        [ "$workspace" -gt 0 ] || continue
        case "$seen" in
            *" $app "*) continue ;;
        esac
        seen="$seen$app "
        jq -cn --arg class "$class" --argjson workspace "$workspace" \
            '{class: $class, workspace: $workspace}' >> "$tmpdir/apps.ndjson" ||
            die "cannot write snapshot entry"
        count=$((count + 1))
    done < "$tmpdir/classes.tsv"

    jq -s --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{version: 1, capturedAt: $at, apps: .}' "$tmpdir/apps.ndjson" > "$tmpdir/out.json" ||
        die "cannot assemble snapshot"
    mv -f "$tmpdir/out.json" "$SNAP" || die "cannot replace $SNAP"
    rm -rf "$tmpdir"
    tmpdir=
    say "snapshot: $count app(s)"
}

cmd_restore() {
    require_tools hyprctl jq
    [ -r "$SNAP" ] || die "no snapshot at $SNAP"
    jq -e '.version == 1 and (.apps | type == "array")' "$SNAP" >/dev/null 2>&1 ||
        die "invalid snapshot at $SNAP"

    signature=${HYPRLAND_INSTANCE_SIGNATURE:-}
    [ -n "$signature" ] || die "HYPRLAND_INSTANCE_SIGNATURE is not set"

    mkdir -p "$STATE_DIR" || die "cannot create $STATE_DIR"
    waited=0
    while ! hyprctl activeworkspace -j >/dev/null 2>&1; do
        [ "$waited" -lt "$WAIT" ] || die "Hyprland is not reachable"
        waited=$((waited + 1))
        sleep 1
    done

    if command -v flock >/dev/null 2>&1; then
        exec 9>"$STATE_DIR/restore.lock" || die "cannot open restore lock"
        flock -n 9 || die "another restore is already running"
    fi

    marker="$STATE_DIR/restored.$(printf '%s\n' "$signature" | tr -c 'A-Za-z0-9._-' '_')"
    if [ -e "$marker" ]; then
        say "restore: already ran for this Hyprland instance"
        return 0
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        say "restore: dry run"
    else
        : > "$marker" || die "cannot write $marker"
    fi

    tmpdir=$(mktemp -d "$STATE_DIR/.restore.XXXXXX") || die "cannot create a temporary directory"
    jq -r '.apps | reverse | .[] | [.class, (.workspace | tostring)] | @tsv' "$SNAP" \
        > "$tmpdir/apps.tsv" || die "cannot read snapshot"

    count=0
    seen=' '
    tab=$(printf '\t')
    while IFS="$tab" read -r class workspace; do
        [ "$count" -lt "$MAX" ] || break
        [ -n "$class" ] || continue
        app=$(command_for_class "$class") || continue
        case "$workspace" in
            ''|*[!0-9]*) continue ;;
        esac
        [ "$workspace" -gt 0 ] || continue
        case "$seen" in
            *" $app "*) continue ;;
        esac
        seen="$seen$app "
        if hyprctl clients -j 2>/dev/null |
            jq -e --arg class "$class" \
                'any(.[]; ((.class // "") | ascii_downcase) == ($class | ascii_downcase))' \
                >/dev/null 2>&1; then
            say "restore: skip $class, already open"
            continue
        fi
        command -v "$app" >/dev/null 2>&1 || {
            say "restore: skip $class, $app is not installed"
            continue
        }
        if [ "$DRY_RUN" -eq 1 ]; then
            say "restore: would open $app on workspace $workspace"
        else
            # The dispatcher takes a rule and a known command, never snapshot
            # text. The workspace id was checked to be a positive integer.
            if hyprctl dispatch exec "[workspace $workspace] $app" >/dev/null 2>&1; then
                say "restore: opened $app on workspace $workspace"
            else
                say "restore: failed to open $app on workspace $workspace"
            fi
            sleep 0.3 2>/dev/null || true
        fi
        count=$((count + 1))
    done < "$tmpdir/apps.tsv"

    rm -rf "$tmpdir"
    tmpdir=
    say "restore: $count app(s)"
}

cmd_show() {
    require_tools jq
    [ -r "$SNAP" ] || die "no snapshot at $SNAP"
    jq -r '"captured " + .capturedAt, (.apps[] | "workspace \(.workspace)\t\(.class)")' "$SNAP" ||
        die "invalid snapshot at $SNAP"
}

cmd_watch() {
    require_tools hyprctl jq
    say "watch: snapshot every ${INTERVAL}s"
    while :; do
        ( cmd_snapshot >/dev/null ) || say "watch: snapshot failed"
        sleep "$INTERVAL"
    done
}

case "$MAX" in
    ''|*[!0-9]*) die "PADILHA_RESTORE_MAX must be an integer" ;;
esac
[ "$MAX" -gt 0 ] || die "PADILHA_RESTORE_MAX must be positive"
[ "$MAX" -le 32 ] || MAX=32
case "$WAIT" in
    ''|*[!0-9]*) die "PADILHA_RESTORE_WAIT must be an integer" ;;
esac
case "$INTERVAL" in
    ''|*[!0-9]*) die "PADILHA_RESTORE_INTERVAL must be an integer" ;;
esac
[ "$INTERVAL" -gt 0 ] || die "PADILHA_RESTORE_INTERVAL must be positive"
[ "$(id -u)" -eq 0 ] && die "refusing to run as root"

action=${1:-}
[ $# -gt 0 ] && shift
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        *) usage ;;
    esac
done

case "$action" in
    snapshot) cmd_snapshot ;;
    restore) cmd_restore ;;
    show) cmd_show ;;
    watch) cmd_watch ;;
    *) usage ;;
esac
