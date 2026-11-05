#!/usr/bin/env bash
# Contract tests for bin/padilha-theme: the promises the theme engine makes to
# every file it writes.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
theme="$root/bin/padilha-theme"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Templates are written under --prefix + the absolute HOME, and the assertions
# below name /home/machine. Pin it so the suite passes as any user (CI is root).
export HOME=/home/machine
unset XDG_CONFIG_HOME XDG_STATE_HOME XDG_DATA_HOME XDG_PICTURES_DIR

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }
check() { if eval "$2"; then ok "$1"; else bad "$1" "${3:-}"; fi; }

echo "colour maths"

if /usr/bin/python3 "$root/tests/theme/check-colour.py" > "$tmp/colour.log" 2>&1; then
    ok "matches the Material reference"
else
    bad "matches the Material reference" "$(tail -3 "$tmp/colour.log")"
fi

echo "scheme"

"$theme" scheme --seed ff1a1a --mode dark --print > "$tmp/dark.json" 2>/dev/null
"$theme" scheme --seed ff1a1a --mode light --print > "$tmp/light.json" 2>/dev/null

check "dark scheme is valid JSON" "/usr/bin/python3 -m json.tool < '$tmp/dark.json' > /dev/null 2>&1"
check "light scheme is valid JSON" "/usr/bin/python3 -m json.tool < '$tmp/light.json' > /dev/null 2>&1"

count=$(/usr/bin/python3 -c "import json;print(len(json.load(open('$tmp/dark.json'))['colours']))")
check "carries every colour the shell asks for" "[ $count -ge 120 ]" "only $count colours"

# The default is black and red: dark surfaces, a red primary, and no hue drift
# into the neutrals.
read -r surface primary light_primary <<<"$(/usr/bin/python3 - "$tmp/dark.json" "$tmp/light.json" <<'PY'
import json, sys
dark = json.load(open(sys.argv[1]))['colours']
light = json.load(open(sys.argv[2]))['colours']
print(dark['surface'], dark['primary'], light['primary'])
PY
)"

tone() {
    /usr/bin/python3 - "$1" "$root" <<'PY'
import sys, subprocess
# Use the engine itself as the oracle: hex -> tone.
out = subprocess.run(["lua", sys.argv[2] + "/tests/theme/dump-colour.lua", sys.argv[2]],
                     input="hex " + sys.argv[1], text=True, capture_output=True).stdout.split()
print(round(float(out[2])))
PY
}

check "dark surface is near black" "[ $(tone "$surface") -le 12 ]" "tone $(tone "$surface")"
check "dark primary is light enough to read" "[ $(tone "$primary") -ge 70 ]" "tone $(tone "$primary")"

echo "templates"

"$theme" apply --seed ff1a1a --mode dark --prefix "$tmp/tree" --no-signals > /dev/null 2>&1
written=$(find "$tmp/tree" -type f | wc -l)
check "apply writes the whole set" "[ $written -ge 14 ]" "only $written files"
check "no template placeholders survive" "! grep -rq '{{' '$tmp/tree'"
check "no empty files" "! find '$tmp/tree' -type f -empty | grep -q ."
check "firefox is skipped without a profile" "! test -e '$tmp/tree/home/machine/.mozilla'"

gtk="$tmp/tree/home/machine/.config/gtk-3.0/gtk.css"
hypr="$tmp/tree/home/machine/.config/hypr/scheme/current.lua"
seq="$tmp/tree/home/machine/.local/state/caelestia/sequences.txt"

check "gtk gets hashed colours" "grep -q 'window_bg_color #' '$gtk'"
check "hypr gets bare colours" "grep -q 'surface = \"' '$hypr'"
check "terminals get OSC 11" "grep -q ']11;rgb:' '$seq'"
check "htop is left alone" "! test -e '$tmp/tree/home/machine/.config/htop/htoprc'"
check "nvtop is left alone" "! test -e '$tmp/tree/home/machine/.config/nvtop/nvtop.colors'"
mc="$tmp/tree/home/machine/.local/share/mc/skins/caelestia.ini"
mc_fg=$(/usr/bin/python3 -c "import json;print(json.load(open('$tmp/tree/home/machine/.local/state/caelestia/scheme.json'))['colours']['onSurface'])")
check "mc gets a skin" "test -s '$mc'"
check "mc surfaces use the terminal background" "grep -qx '    Main = default' '$mc' && grep -qx '    Dialog = default' '$mc'"
check "no mc surface is opaque" "! grep -Eq '^    (Main|Dialog|Input|Top|Menu|Bottom|Help|ShadowBg|EditorVoid|EditorLineNumber) = #' '$mc'"
check "mc foregrounds keep the scheme" "grep -qx \"    MainFg = #$mc_fg\" '$mc'"
check "mc selection stays an opaque accent" "grep -Eq '^    Selected = #[0-9a-fA-F]{6}\$' '$mc'"
check "mc sections use the generated aliases" "grep -q '^    _default_ = MainFg;Main$' '$mc'"
check "mc sections carry no frozen colours" "! sed -n '/^\\[core\\]/,\$p' '$mc' | grep -Eq '#[0-9a-fA-F]{6}'"

bar="$tmp/tree/home/machine/.local/state/caelestia/scheme-bar.json"
check "the pinned bar palette is written" "test -s '$bar'"
bar_bg=$(/usr/bin/python3 -c "import json;print(json.load(open('$bar'))['colours']['background'])")
check "the pinned bar palette is black" "[ \"$bar_bg\" = 000000 ]" "background $bar_bg"

check "spicetify gets a colour.ini" "test -s '$tmp/tree/home/machine/.config/spicetify/Themes/caelestia/color.ini'"

mkdir -p "$tmp/tree/home/machine/.config/Equicord"
"$theme" apply --seed ff1a1a --mode dark --prefix "$tmp/tree" --no-signals > /dev/null 2>&1
discord="$tmp/tree/home/machine/.config/Equicord/themes/caelestia.theme.css"
check "discord clients get a compiled theme" "test -s '$discord'"
check "the discord theme carries the palette" "grep -q '#ffb4a6\|#ffb4ab\|#ffb4a9' '$discord'"

echo "firefox"

# Apply into a scratch HOME whose profiles.ini has a non-default first profile
# and a Default=1 second one. Only the default profile may be written.
#
# The generated stylesheet was chrome/lilith.css before the rebrand; prefer
# chrome/padilha.css but accept the old name while the engine is being renamed.
ff_css() {
    local dir=$1
    if [ -s "$dir/chrome/padilha.css" ]; then
        printf '%s\n' "$dir/chrome/padilha.css"
    elif [ -s "$dir/chrome/lilith.css" ]; then
        printf '%s\n' "$dir/chrome/lilith.css"
    else
        printf '%s\n' "$dir/chrome/padilha.css"
    fi
}

ff_root="$tmp/firefox/home/machine/.mozilla/firefox"
mkdir -p "$ff_root/notdefault.default" "$ff_root/padilha.default-release"
cat > "$ff_root/profiles.ini" <<'INI'
[Profile0]
Name=notdefault
IsRelative=1
Path=notdefault.default

[Profile1]
Name=default-release
IsRelative=1
Path=padilha.default-release
Default=1

[Install4F96D1932A9F858E]
Default=padilha.default-release
Locked=1
INI
"$theme" apply --seed ff1a1a --mode dark --prefix "$tmp/firefox" --no-signals > /dev/null 2>&1
ffcss=$(ff_css "$ff_root/padilha.default-release")
ff_scheme="$tmp/firefox/home/machine/.local/state/caelestia/scheme.json"
ff_bg=$(/usr/bin/python3 -c "import json;print(json.load(open('$ff_scheme'))['colours']['background'])")
ff_primary=$(/usr/bin/python3 -c "import json;print(json.load(open('$ff_scheme'))['colours']['primary'])")
ff_outline=$(/usr/bin/python3 -c "import json;print(json.load(open('$ff_scheme'))['colours']['outline'])")
ff_prefix=padilha
if grep -q '^  --lilith-' "$ffcss" 2>/dev/null; then ff_prefix=lilith; fi
check "firefox palette lands in the default profile" "test -s '$ffcss'"
check "firefox skips a non-default profile" "! test -e '$ff_root/notdefault.default/chrome'"
check "firefox palette substitutes the background" "grep -qx '  --$ff_prefix-bg: #$ff_bg;' '$ffcss'"
check "firefox palette substitutes the primary" "grep -qx '  --$ff_prefix-primary: #$ff_primary;' '$ffcss'"
check "firefox palette substitutes the outline" "grep -qx '  --$ff_prefix-outline: #$ff_outline;' '$ffcss'"
check "firefox palette records the mode" "grep -qx '  --$ff_prefix-scheme: Dark;' '$ffcss'"
check "firefox palette has no placeholders" "! grep -q '{{' '$ffcss'"

# With no Default=1 the [Install...] Default must win over the first profile.
ff_install_root="$tmp/firefox-install/home/machine/.mozilla/firefox"
mkdir -p "$ff_install_root/first.default" "$ff_install_root/install.default-release"
cat > "$ff_install_root/profiles.ini" <<'INI'
[Profile0]
Name=first
IsRelative=1
Path=first.default

[Install4F96D1932A9F858E]
Default=install.default-release
Locked=1
INI
"$theme" apply --seed ff1a1a --mode dark --prefix "$tmp/firefox-install" --no-signals > /dev/null 2>&1
ff_install_css=$(ff_css "$ff_install_root/install.default-release")
check "firefox falls back to the Install Default" "test -s '$ff_install_css'"
check "firefox does not guess the first profile" "! test -e '$ff_install_root/first.default/chrome'"

# Flatpak is a separate candidate root; a native tree without profiles.ini
# must not shadow it.
ff_flatpak="$tmp/firefox-flatpak/home/machine/.var/app/org.mozilla.firefox/.mozilla/firefox"
mkdir -p "$ff_flatpak/flatpak.default-release"
cat > "$ff_flatpak/profiles.ini" <<'INI'
[Profile0]
Name=default-release
IsRelative=1
Path=flatpak.default-release
Default=1
INI
"$theme" apply --seed ff1a1a --mode dark --prefix "$tmp/firefox-flatpak" --no-signals > /dev/null 2>&1
ff_flatpak_css=$(ff_css "$ff_flatpak/flatpak.default-release")
check "firefox finds the Flatpak profile" "test -s '$ff_flatpak_css'"

# A non-standard profile can be handed to both the installer and the engine.
ff_custom="$tmp/firefox-custom/home/machine/nonstandard"
mkdir -p "$ff_custom"
PADILHA_FIREFOX_PROFILE_DIR=/home/machine/nonstandard \
LILITH_FIREFOX_PROFILE_DIR=/home/machine/nonstandard "$theme" apply \
    --seed ff1a1a --mode dark --prefix "$tmp/firefox-custom" --no-signals > /dev/null 2>&1
ff_custom_css=$(ff_css "$ff_custom")
check "firefox honours the profile directory override" "test -s '$ff_custom_css'"

# Exercise the dotfiles installer when the sibling checkout is present.
dots="$root/../maria-padilha-dotfiles/bin/padilha-dots"
if [ -x "$dots" ]; then
    ff_home="$tmp/dots-home"
    mkdir -p "$ff_home/.mozilla/firefox/abc.default-release" "$ff_home/.config"
    cat > "$ff_home/.mozilla/firefox/profiles.ini" <<'INI'
[Profile0]
Name=default-release
IsRelative=1
Path=abc.default-release
Default=1
INI
    HOME="$ff_home" XDG_CONFIG_HOME="$ff_home/.config" "$dots" firefox > /dev/null 2>&1
    ff_installed="$ff_home/.mozilla/firefox/abc.default-release"
    check "padilha-dots copies user.js" "test -f '$ff_installed/user.js' && [ ! -L '$ff_installed/user.js' ]"
    check "padilha-dots links userChrome.css" "[ -L '$ff_installed/chrome/userChrome.css' ]"
    check "padilha-dots links userContent.css" "[ -L '$ff_installed/chrome/userContent.css' ]"
    check "padilha-dots leaves prefs.js alone" "! test -e '$ff_installed/prefs.js'"

    ff_empty="$tmp/dots-empty"
    mkdir -p "$ff_empty"
    if HOME="$ff_empty" XDG_CONFIG_HOME="$ff_empty/.config" "$dots" firefox > /dev/null 2>&1; then
        ok "padilha-dots skips a missing profile without failing"
    else
        bad "padilha-dots skips a missing profile without failing"
    fi
else
    printf '  skip %s\n' "padilha-dots not checked out"
fi

echo "modes differ"

"$theme" apply --seed ff1a1a --mode light --prefix "$tmp/light-tree" --no-signals > /dev/null 2>&1
light_surface=$(tone "$(/usr/bin/python3 -c "import json;print(json.load(open('$tmp/light-tree/home/machine/.local/state/caelestia/scheme.json'))['colours']['surface'])")")
check "light mode has a light surface" "[ $light_surface -ge 90 ]" "tone $light_surface"

echo "daylight"

daylight="$root/bin/padilha-daylight"
hour=$((10#$(date +%H)))
if [ "$hour" -ge 6 ] && [ "$hour" -lt 18 ]; then
    want=day; wantmode=light; wantwall=day.jpg
else
    want=night; wantmode=dark; wantwall=night.jpg
fi
out=$("$daylight" --dry-run 2>&1)
check "dry run follows the clock" "printf '%s' \"$out\" | grep -q \"period=$want mode=$wantmode wallpaper=.*$wantwall\"" "$out"

rm -rf "$tmp/day"
"$daylight" --once --prefix "$tmp/day" > /dev/null 2>&1
check "a switch writes the wallpaper state" "test -s '$tmp/day/home/machine/.local/state/caelestia/wallpaper/path.txt'"
check "a switch writes the scheme" "test -s '$tmp/day/home/machine/.local/state/caelestia/scheme.json'"

surface=$(/usr/bin/python3 -c "import json;print(json.load(open('$tmp/day/home/machine/.local/state/caelestia/scheme.json'))['colours']['surface'])")
if [ "$wantmode" = dark ]; then
    check "the shipped default is black" "[ $(tone "$surface") -le 12 ]" "tone $(tone "$surface")"
else
    check "the shipped default is white" "[ $(tone "$surface") -ge 90 ]" "tone $(tone "$surface")"
fi

echo "unknown colours fail loudly"

cat > "$tmp/bad.lua" <<'LUA'
return "{{ $notAColour }}"
LUA
# The renderer is only reachable through a template; use the module directly.
if lua -e "package.path='$root/lib/?.lua;'..package.path; local t=require('template'); t.render('{{ \$nope }}', {})" > /dev/null 2>&1; then
    bad "a missing colour is an error"
else
    ok "a missing colour is an error"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
