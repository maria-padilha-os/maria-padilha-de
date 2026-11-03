# Templates

Every file here is a Padilha template: `{{ $colour }}` where a colour from
`scheme.json` goes, `{{ $mode }}` where `Light`/`Dark` goes.

They started as the Caelestia 2.5.0 set (GPL-3.0, like the shell this desktop
descends from) and are ours to change from here. A template may ask for any
role the scheme produces; `bin/padilha-theme apply` fails loudly if a name is
missing rather than writing a file with a hole in it.
