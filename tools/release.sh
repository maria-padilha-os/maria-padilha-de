#!/bin/sh
# Cut a release: test, export HEAD as the tarball the PKGBUILD builds from,
# and say what is left for a human to do.
#
#   tools/release.sh            export and build the package
#   tools/release.sh --export   only export the tarball
#
# Refuses to run on a dirty tree. Does not tag: tagging is a decision, not a
# side effect.
set -eu

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

version=$(sed -n 's/^pkgver=//p' packaging/PKGBUILD)
[ -n "$version" ] || {
    echo "release: cannot read pkgver from packaging/PKGBUILD" >&2
    exit 1
}

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "release: working tree is dirty; commit first" >&2
    exit 1
fi

describe=$(git describe --tags --always --dirty 2>/dev/null || echo "no tags")
echo "release: head is $describe, version $version"

"$root/tests/all.sh" > /dev/null || {
    echo "release: tests failed; run tests/all.sh to see it" >&2
    exit 1
}
echo "release: tests pass"

tarball="packaging/padilha-$version.tar.gz"
# The recipe and the tarball must not contain each other.
git archive --format=tar.gz --prefix="padilha-$version/" \
    -o "$tarball" HEAD -- . ':(exclude)packaging'
echo "release: wrote $tarball ($(du -h "$tarball" | cut -f1))"

if [ "${1:-}" = "--export" ]; then
    exit 0
fi

cd packaging
makepkg -f --nocheck
echo
echo "release: package built. Install it with:"
echo "    sudo pacman -U $root/packaging/padilha-$version-1-x86_64.pkg.tar.zst"
