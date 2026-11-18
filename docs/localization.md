---
layout: default
title: Localization
---

# Localization

The shell, settings, bundled extensions and desktop entries ship in English
and Brazilian Portuguese. The source strings stay in English; gettext catalogs
provide every other language. There is no second JSON/YAML string system.

## How it fits together

- `shell/plugin/src/Caelestia/I18n/` contains the `Tr` singleton, the `.mo`
  loader and the plural-rule parser.
- `shell/plugin/src/Caelestia/I18n/trs/en.po` is the explicit English catalog,
  so English stays selectable when the system locale is Portuguese.
- `shell/plugin/src/Caelestia/I18n/trs/pt_BR.po` is the Brazilian Portuguese
  catalog.
- `shell/scripts/trs.fish` regenerates the POT with `xgettext`; it scans QML,
  JavaScript and C++ in `shell/`, the bundled QML under `extensions/` and
  `share/extensions/`, and the `name`/`description` fields of every
  `extension.json`.
- `shell/plugin/src/Caelestia/I18n/CMakeLists.txt` compiles each `.po` to a
  resource named `<language>.mo`; the language picker lists those resources.
- Desktop files use the standard `Name[pt_BR]`, `Comment[pt_BR]` and related
  localized keys. The desktop environment, not the shell catalog, resolves
  them.

## Writing a translatable string

Use the existing helpers and keep the English source in place:

```qml
text: Tr.tr("Clear search")
text: Tr.trCtx("Saved", "network saved")
text: Tr.trN("%n notification", "%n notifications", Notifs.list.length)
```

- Add context when the same English word has different genders or meanings,
  for example `Saved` for a network (`Salva`) and a device (`Salvo`).
- Use `Tr.trN`/`Tr.trCtxN` for counts. The source must use `%n`, and the
  translator keeps `%n` in both plural forms.
- Use `Tr.mark(...)` for strings produced outside a QML binding, then
  `Tr.trMarked(...)` when displaying them.
- Keep paths, command names, key names, product names and format placeholders
  unchanged.
- Run `python3 shell/scripts/trs-check.py` before committing. It catches
  helper arity, empty sources, mismatched `.arg()` chains, `qsTr()` and missing
  `Caelestia.I18n` imports.

After adding or changing source strings, regenerate and update both catalogs:

```sh
cd shell
fish scripts/trs.fish raw
msgmerge --update plugin/src/Caelestia/I18n/trs/pt_BR.po plugin/src/Caelestia/I18n/trs/raw.pot
msgmerge --update plugin/src/Caelestia/I18n/trs/en.po plugin/src/Caelestia/I18n/trs/raw.pot
# English is the identity catalog: fill any newly merged empty entries.
msgen -o plugin/src/Caelestia/I18n/trs/en.po.new plugin/src/Caelestia/I18n/trs/en.po
mv plugin/src/Caelestia/I18n/trs/en.po.new plugin/src/Caelestia/I18n/trs/en.po
```

Do not commit `raw.pot`; it is generated from the source tree. The tests
regenerate it in a temporary directory.

## Dates, units and long strings

- User-visible dates and times use `Units.locale` (`Locale.toString` or
  `toLocaleDateString`) so the selected UI language controls month names,
  date order and the 12/24-hour guess. Do not call `Qt.formatDateTime` with the
  default locale for user-facing dates.
- Temperatures, data sizes and network rates go through `Units`; do not
  hard-code `°C`, `MiB` or `GB/s` in a page.
- `Language & region` controls both the UI language and the `Auto` unit/clock
  guesses. `TemperatureUnit.Auto` uses the selected locale's country.
- Long labels in settings rows and section headers wrap or elide instead of
  clipping. When adding a row, give labels and subtexts a `wrapMode` and a
  finite `maximumLineCount`, or `elide: Text.ElideRight` on a single line.
- Date format strings are translatable with `Tr.trCtx("MMM d", "short date
  format")`; the translation contains the day/month order and separators.

## Automated checks

```sh
bash tests/localization/run.sh
bash tests/all.sh
make lint
```

`tests/localization/check.py` regenerates the POT and fails when:

- a source string is missing from `en.po` or `pt_BR.po`, or a catalog contains
  a stale string;
- a translation is empty, fuzzy, or has a different placeholder set;
- a plural entry does not match the catalog's `Plural-Forms` count;
- `msgfmt --check-format` rejects a catalog;
- an extension manifest name/description is not in both catalogs;
- a desktop file lacks its `[pt_BR]` keys.

## Manual language-switch checklist

Use a spare workspace or an offscreen session; do not record the live desktop.

1. Open **Settings → Language & region → UI language**.
2. Choose **Português (Brasil)**. The page should redraw without a restart.
3. Check the bar: clock, date, workspace labels, status icons, battery,
   network, Bluetooth, media, tray menu and power menu.
4. Open the dashboard and every built-in tab: Overview, Media, Performance and
   Weather. Check the forecast weekday/date labels and temperature units.
5. Open the launcher, type a query, open an app, a calculator result, an
   action and a wallpaper result. Check the empty and no-result states.
6. Open Settings and visit every page: Wallpaper & style, Display, Network,
   Connected devices, Audio, Updates, Extensions, Power, Panels, Apps,
   Services, Keybinds, Language & region and About. Check section headers,
   long descriptions, toggles, menus, dialogs and validation errors.
7. Open the session menu, notifications, OSD, clipboard history, power menu
   and window info. Check dates, counts and plural forms.
8. Lock and unlock the session. Check the lock clock date, weather forecast
   and PAM messages.
9. Open each bundled extension: Calculator, Colour picker, Disk usage, Files,
   Maps, Pomodoro, Stopwatch, System monitor, Translator, Tuner, Calendar,
   Notes and Unit converter. Check titles, empty states, buttons, tooltips and
   accessibility names.
10. In Files, open the file dialog. Check **Início**, **Downloads**,
    **Documentos**, **Imagens**, **Vídeos** and breadcrumbs.
11. In Translator, check the language names, character counter, status line
    and the two pickers at `480×280`.
12. Check dates and units: a forecast day should read like
    `qua, 18 de nov`, a full date like `quarta-feira, 18 de novembro`, and
    temperatures should follow the selected unit.
13. Narrow the settings window and the dashboard. Long Portuguese strings must
    wrap, elide or scroll; no button, value or row may be clipped.
14. Switch back to **English** and repeat steps 3–13. English dates should use
    the English date order and month names.
15. Restart the shell once (deliberately, not through the watchdog) and confirm
    the saved language and all formatting still match.
16. Open the application menu and confirm the mail launcher shows **Correio**
    / **E-mail** under Portuguese and **Mail** / **Email** under English.

Note any clipped string with its window size and page. Add a regression check
to `tests/localization/check.py` or the relevant layout suite before fixing it.
