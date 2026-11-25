# Maria Padilha greeter

This is a separate Quickshell configuration for the login screen. It uses
`Quickshell.Services.Greetd`, so authentication stays in greetd/PAM and no
password ever passes through the shell session.

It is currently opt-in: the host image still uses LightDM, and the ISO still
uses the tuigreet wrapper. Do not replace either until it has been tested in
cage.

## Run the UI against the current session

```sh
qs -p share/greeter
```

`Greetd.available` is false outside greetd; the card says so. This is useful
for layout work, but it is not a login.

## Run through greetd + cage

```toml
# /etc/greetd/config.toml
[terminal]
vt = 1

[default_session]
command = "/usr/bin/cage -- /usr/bin/padilha-greeter"
user = "greeter"
```

Dependencies: `greetd`, `cage`, `quickshell`, and the Maria Padilha package
that installs `padilha-greeter` and this directory.

The greeter launches `dbus-run-session -- hyprland` with the Wayland session
environment. The package must be installed for `/usr/bin/padilha-greeter` to
resolve.

## Tests

```sh
bash tests/greeter/run.sh
```

The test starts a fake greetd Unix socket, drives `create_session` →
`auth_message` → `start_session`, and asserts the launch; it also loads this
configuration offscreen. It never touches the real display manager.
