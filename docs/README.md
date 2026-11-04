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

## Local preview

Jekyll is not installed by the desktop package. On a machine where Ruby is
available:

```sh
gem install --user-install --no-document jekyll minima erb csv logger
gem_bin=$(ruby -e 'print File.join(Gem.user_dir, "bin")')
"$gem_bin/jekyll" build --source docs --destination /tmp/padilha-docs --baseurl ""
python3 -m http.server --directory /tmp/padilha-docs 4000
```

The minima theme emits Sass deprecation warnings; the build itself succeeds.
`baseurl` is `/padilha`; the generated `/padilha/...` links therefore preview
correctly when the site is served under that prefix, or after Pages is enabled.

`baseurl` in `_config.yml` is `/padilha`; change it if the GitHub repository is
renamed.
