# Templates

Every file here is a Maria Padilha template: `{{ $colour }}` where a colour from
`scheme.json` goes, `{{ $mode }}` where `Light`/`Dark` goes. Colours that have
to be `r,g,b` rather than `#rrggbb` use `{{ $colour | rgb }}`; this exists for
the KDE window-manager blend fields in the Qt colour schemes.

They started as the Caelestia 2.5.0 set (GPL-3.0, like the shell this desktop
descends from) and are ours to change from here. A template may ask for any
role the scheme produces; `bin/padilha-theme apply` fails loudly if a name is
missing rather than writing a file with a hole in it.

`discord.scss` is the exception that ships as SCSS: `padilha-theme apply`
compiles it with the generated palette and writes a standalone
BetterDiscord/Vencord stylesheet only when `enableDiscord` is explicitly on.
It must not import remote CSS or assets, and the theme engine must never
install or patch Discord or the client mod; the user does that manually.
