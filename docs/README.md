# GitHub Pages source

This directory is a Jekyll site for `https://maria-padilha-os.github.io/maria-padilha-de/`.

It is published from the public repository with Pages source **main /docs**
(Settings → Pages → Deploy from a branch). The site is intentionally one
org-level documentation site with sections for the desktop, the dotfiles, and
(later) the OS image — not a separate Pages site per repository.

## Local preview

Jekyll is not installed by the desktop package. On a machine where Ruby is
available:

```sh
gem install --user-install --no-document jekyll minima erb csv logger
gem_bin=$(ruby -e 'print File.join(Gem.user_dir, "bin")')
"$gem_bin/jekyll" build --source docs --destination /tmp/maria-padilha-docs --baseurl ""
python3 -m http.server --directory /tmp/maria-padilha-docs 4000
```

The minima theme emits Sass deprecation warnings; the build itself succeeds.
`baseurl` is `/maria-padilha-de`; the generated `/maria-padilha-de/...` links
therefore preview correctly when the site is served under that prefix, or after
Pages is enabled.

`baseurl` in `_config.yml` is `/maria-padilha-de`, matching the repository name;
change it if the GitHub repository is renamed.
