# GitHub Pages source

This directory is a Jekyll site for `https://mateus-m-reis.github.io/padilha/`.

Publish it once from the repository settings:

1. **Settings → Pages**
2. Source: **Deploy from a branch**
3. Branch: **main**, folder: **/docs**
4. Save.

If the repository is private, GitHub Pages may require a paid plan; alternatively
publish from a public `padilha-docs` mirror. The site is intentionally one
org-level documentation site with sections for the desktop, the dotfiles, and
(later) the OS image — not a separate Pages site per repository.

`baseurl` in `_config.yml` is `/padilha`; change it if the GitHub repository is
renamed.
